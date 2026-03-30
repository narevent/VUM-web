from django.shortcuts import render, get_object_or_404, redirect
from django.contrib import messages
from django.utils import timezone
from django.core.paginator import Paginator
from django.http import JsonResponse
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
import stripe
from .models import GameSession, Booking, TicketType
from .forms import BookingForm
from sections.models import Header


def sessions_list(request):
    """
    List sessions grouped by event.

    Layout:
      - Active events whose earliest upcoming session falls within the date
        filter are shown as large event cards, with each of their upcoming
        sessions listed as bookable timeslot rows inside.
      - Sessions with no event attached are shown as standalone cards below.
    """
    from .models import Event
    from django.db.models import Prefetch

    date_from = request.GET.get('date_from')
    date_to   = request.GET.get('date_to')
    today     = timezone.now().date()

    # Base queryset — upcoming, active sessions only
    base_qs = (
        GameSession.objects
        .filter(date__gte=today, is_active=True)
        .select_related('event')
        .prefetch_related('bookings')
        .order_by('date', 'start_time')
    )
    if date_from:
        base_qs = base_qs.filter(date__gte=date_from)
    if date_to:
        base_qs = base_qs.filter(date__lte=date_to)

    # Fetch events that have at least one upcoming session in the filter window
    events_qs = (
        Event.objects
        .filter(is_active=True, sessions__in=base_qs)
        .prefetch_related(
            Prefetch(
                'sessions',
                queryset=base_qs.filter(event__isnull=False),
                to_attr='upcoming_sessions',
            ),
            Prefetch('ticket_types', to_attr='active_ticket_types'),
        )
        .distinct()
    )

    # Deduplicate while preserving earliest-session order
    seen = set()
    event_cards = []
    for event in events_qs:
        if event.id not in seen:
            seen.add(event.id)
            event_cards.append(event)
    event_cards.sort(
        key=lambda e: e.upcoming_sessions[0].date if e.upcoming_sessions else today
    )

    # Standalone sessions that belong to no event
    standalone_sessions = base_qs.filter(event__isnull=True)

    header = Header.objects.filter(page='sessions').first()

    context = {
        'event_cards':         event_cards,
        'standalone_sessions': standalone_sessions,
        'date_from':           date_from,
        'date_to':             date_to,
        'header':              header,
    }
    return render(request, 'games/sessions.html', context)


def booking_success(request, access_token):
    booking = get_object_or_404(
        Booking.objects.select_related('session', 'ticket_type'),
        access_token=access_token,
    )
    return render(request, 'games/booking_success.html', {'booking': booking})


def check_availability(request, session_id):
    """AJAX endpoint to check session availability"""
    session = get_object_or_404(GameSession, id=session_id)
    return JsonResponse({
        'available_spots': session.available_spots,
        'is_full': session.is_full,
        'max_participants': session.max_participants,
    })


def book_session(request, session_id):
    """Booking view — supports both legacy (price_per_person) and ticket-type pricing."""
    session = get_object_or_404(
        GameSession.objects.select_related('event'),
        id=session_id,
        is_active=True,
    )

    if not session.is_upcoming:
        messages.error(request, 'This session has already passed.')
        return redirect('sessions_list')

    if session.is_full:
        messages.error(request, 'This session is fully booked.')
        return redirect('sessions_list')

    # Ticket types for this session's event (empty queryset if no event attached)
    ticket_types = session.ticket_types

    if request.method == 'POST':
        form = BookingForm(request.POST, session=session)

        # ── Ticket-type pricing path ──────────────────────────────────────
        if session.has_ticket_types:
            ticket_type_id = request.POST.get('ticket_type_id')
            ticket_quantity = int(request.POST.get('ticket_quantity', 1))

            try:
                ticket_type = ticket_types.get(id=ticket_type_id)
            except TicketType.DoesNotExist:
                messages.error(request, 'Please select a valid ticket type.')
                return render(request, 'games/booking.html', {
                    'form': form,
                    'session': session,
                    'ticket_types': ticket_types,
                })

            spots_needed = ticket_type.participant_count * ticket_quantity
            if spots_needed > session.available_spots:
                messages.error(request, 'Not enough spots available for the selected tickets.')
                return render(request, 'games/booking.html', {
                    'form': form,
                    'session': session,
                    'ticket_types': ticket_types,
                })

            if form.is_valid():
                booking = form.save(commit=False)
                booking.session = session
                booking.ticket_type = ticket_type
                booking.ticket_quantity = ticket_quantity
                # participants & total_price are computed in Booking.save()
                booking.save()

                _finalize_booking(request, booking, session)
                return _redirect_after_booking(booking)

        # ── Legacy / fallback pricing path ───────────────────────────────
        else:
            if form.is_valid():
                booking = form.save(commit=False)
                booking.session = session

                if booking.participants > session.available_spots:
                    messages.error(request, 'Not enough spots available.')
                    return render(request, 'games/booking.html', {
                        'form': form,
                        'session': session,
                        'ticket_types': ticket_types,
                    })

                booking.save()
                _finalize_booking(request, booking, session)
                return _redirect_after_booking(booking)

    else:
        form = BookingForm(session=session)

    context = {
        'form': form,
        'session': session,
        'ticket_types': ticket_types,
        'stripe_public_key': settings.STRIPE_PUBLISHABLE_KEY,
    }
    return render(request, 'games/booking.html', context)


# ── Private helpers ───────────────────────────────────────────────────────────

def _finalize_booking(request, booking, session):
    """Confirm free bookings immediately; paid ones proceed to the payment page."""
    is_free = (
        booking.total_price == 0
        or (not session.has_ticket_types and session.price_per_person == 0)
    )
    if is_free:
        booking.payment_status = 'completed'
        booking.is_confirmed = True
        booking.status = 'confirmed'
        booking.save()
        send_booking_confirmation_email(booking)


def _redirect_after_booking(booking):
    if booking.payment_status == 'completed':
        return redirect('booking_success', access_token=booking.access_token)
    booking.create_payment_intent()
    return redirect('payment', access_token=booking.access_token)


# ── Payment ───────────────────────────────────────────────────────────────────

def payment(request, access_token):
    booking = get_object_or_404(
        Booking.objects.select_related('session', 'ticket_type'),
        access_token=access_token,
    )

    # Cash payment
    if request.method == 'POST' and request.POST.get('payment_method') == 'cash':
        booking.payment_method = 'cash'
        booking.payment_status = 'pending'
        booking.is_confirmed = True
        booking.status = 'confirmed'
        booking.save()
        send_cash_payment_confirmation_email(booking)
        messages.success(request, 'Booking confirmed! Please bring cash to the event.')
        return redirect('booking_success', access_token=booking.access_token)

    # Already paid
    if booking.payment_status == 'completed':
        return redirect('booking_success', access_token=booking.access_token)

    # Create / retrieve Stripe payment intent
    if not booking.stripe_payment_intent_id:
        payment_intent = booking.create_payment_intent()
    else:
        stripe.api_key = settings.STRIPE_SECRET_KEY
        payment_intent = stripe.PaymentIntent.retrieve(booking.stripe_payment_intent_id)

    context = {
        'booking': booking,
        'client_secret': payment_intent.client_secret if payment_intent else None,
        'stripe_public_key': settings.STRIPE_PUBLISHABLE_KEY,
        'paypal_client_id': getattr(settings, 'PAYPAL_CLIENT_ID', ''),
    }
    return render(request, 'games/payment.html', context)


# ── Webhooks ──────────────────────────────────────────────────────────────────

@csrf_exempt
@require_POST
def stripe_webhook(request):
    """Handle Stripe webhook events"""
    payload = request.body
    sig_header = request.META.get('HTTP_STRIPE_SIGNATURE')
    endpoint_secret = settings.STRIPE_WEBHOOK_SECRET

    try:
        event = stripe.Webhook.construct_event(payload, sig_header, endpoint_secret)
    except ValueError:
        return JsonResponse({'error': 'Invalid payload'}, status=400)
    except stripe.error.SignatureVerificationError:
        return JsonResponse({'error': 'Invalid signature'}, status=400)

    if event['type'] == 'payment_intent.succeeded':
        payment_intent = event['data']['object']
        booking_id = payment_intent['metadata']['booking_id']

        try:
            booking = Booking.objects.get(id=booking_id)

            if booking.payment_status == 'completed':
                return JsonResponse({'status': 'already processed'})

            booking.payment_status = 'completed'
            booking.is_confirmed = True
            booking.status = 'confirmed'
            booking.payment_completed_at = timezone.now()
            booking.payment_method = payment_intent.get('payment_method_types', ['card'])[0]
            booking.save()

            send_booking_confirmation_email(booking)

        except Booking.DoesNotExist:
            pass

    return JsonResponse({'status': 'success'})


@csrf_exempt
@require_POST
def paypal_webhook(request):
    """Handle PayPal webhook events"""
    import json

    try:
        data = json.loads(request.body)
        event_type = data.get('event_type')

        if event_type == 'PAYMENT.CAPTURE.COMPLETED':
            resource = data.get('resource', {})
            booking_reference = resource.get('custom_id')

            if booking_reference:
                try:
                    booking = Booking.objects.get(booking_reference=booking_reference)
                    booking.payment_status = 'completed'
                    booking.is_confirmed = True
                    booking.status = 'confirmed'
                    booking.payment_method = 'paypal'
                    booking.payment_completed_at = timezone.now()
                    booking.save()

                    send_booking_confirmation_email(booking)

                except Booking.DoesNotExist:
                    pass

        return JsonResponse({'status': 'success'})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=400)


# ── Email helpers ─────────────────────────────────────────────────────────────

def send_booking_confirmation_email(booking):
    subject = f'Booking Confirmation - {booking.booking_reference}'

    text_content = render_to_string('emails/booking_confirmation.txt', {
        'booking': booking,
        'session': booking.session,
    })
    html_content = render_to_string('emails/booking_confirmation.html', {
        'booking': booking,
        'session': booking.session,
    })

    email = EmailMultiAlternatives(
        subject=subject,
        body=text_content,
        from_email=settings.DEFAULT_FROM_EMAIL,
        to=[booking.customer_email],
    )
    email.attach_alternative(html_content, "text/html")

    try:
        email.send()
    except Exception as e:
        print(f"Email sending failed: {e}")


def send_cash_payment_confirmation_email(booking):
    subject = f'Booking Confirmed - Pay at Event - {booking.booking_reference}'

    text_content = render_to_string('emails/cash_booking_confirmation.txt', {
        'booking': booking,
        'session': booking.session,
    })
    html_content = render_to_string('emails/cash_booking_confirmation.html', {
        'booking': booking,
        'session': booking.session,
    })

    email = EmailMultiAlternatives(
        subject=subject,
        body=text_content,
        from_email=settings.DEFAULT_FROM_EMAIL,
        to=[booking.customer_email],
    )
    email.attach_alternative(html_content, "text/html")

    try:
        email.send()
    except Exception as e:
        print(f"Email sending failed: {e}")