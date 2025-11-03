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
from .models import GameSession, Booking
from .forms import BookingForm
from sections.models import Header

def sessions_list(request):
    """List all available gaming sessions"""
    sessions = GameSession.objects.filter(
        date__gte=timezone.now().date(),
        is_active=True
    ).order_by('date', 'start_time')
    
    # Filter by date range if provided
    date_from = request.GET.get('date_from')
    date_to = request.GET.get('date_to')
    game_type = request.GET.get('game_type')
    
    if date_from:
        sessions = sessions.filter(date__gte=date_from)
    if date_to:
        sessions = sessions.filter(date__lte=date_to)
    if game_type:
        sessions = sessions.filter(game_type=game_type)
    
    # Pagination
    paginator = Paginator(sessions, 12)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)

    header = Header.objects.filter(page='sessions').first()
    
    context = {
        'page_obj': page_obj,
        'game_types': GameSession.GAME_TYPES,
        'selected_game_type': game_type,
        'date_from': date_from,
        'date_to': date_to,
        'header': header,
    }
    return render(request, 'games/sessions.html', context)

def booking_success(request, access_token):
    booking = get_object_or_404(Booking, access_token=access_token)
    return render(request, 'games/booking_success.html', {'booking': booking})

def check_availability(request, session_id):
    """AJAX endpoint to check session availability"""
    session = get_object_or_404(GameSession, id=session_id)
    return JsonResponse({
        'available_spots': session.available_spots,
        'is_full': session.is_full,
        'max_participants': session.max_participants
    })

def book_session(request, session_id):
    """Enhanced booking with payment integration"""
    session = get_object_or_404(GameSession, id=session_id, is_active=True)
    
    if not session.is_upcoming:
        messages.error(request, 'This session has already passed.')
        return redirect('sessions_list')
    
    if session.is_full:
        messages.error(request, 'This session is fully booked.')
        return redirect('sessions_list')
    
    if request.method == 'POST':
        form = BookingForm(request.POST, session=session)
        if form.is_valid():
            booking = form.save(commit=False)
            booking.session = session
            
            # Check availability again
            if booking.participants > session.available_spots:
                messages.error(request, 'Not enough spots available.')
                return render(request, 'games/booking.html', {
                    'form': form, 'session': session
                })
            
            booking.save()
            
            # Create payment intent
            payment_intent = booking.create_payment_intent()
            if payment_intent:
                return redirect('payment', access_token=booking.access_token)
            else:
                # Fallback to confirmation without payment
                messages.success(request, f'Booking confirmed! Reference: {booking.booking_reference}')
                return redirect('booking_success', access_token=booking.access_token)
    else:
        form = BookingForm(session=session)
    
    context = {
        'form': form,
        'session': session,
        'stripe_public_key': settings.STRIPE_PUBLISHABLE_KEY,
    }
    return render(request, 'games/booking.html', context)

def payment(request, access_token):
    booking = get_object_or_404(Booking, access_token=access_token)
    
    # Handle cash payment selection
    if request.method == 'POST' and request.POST.get('payment_method') == 'cash':
        booking.payment_method = 'cash'
        booking.payment_status = 'pending'
        booking.is_confirmed = True
        booking.status = 'confirmed'
        booking.save()
        
        # Send confirmation email with cash payment instructions
        send_cash_payment_confirmation_email(booking)
        messages.success(request, 'Booking confirmed! Please bring cash to the event.')
        return redirect('booking_success', access_token=booking.access_token)
    
    if booking.payment_status == 'completed':
        return redirect('booking_success', access_token=booking.access_token)
    
    # Create or get payment intent for card/Revolut payments
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

@csrf_exempt
@require_POST
def stripe_webhook(request):
    """Handle Stripe webhook events"""
    payload = request.body
    sig_header = request.META.get('HTTP_STRIPE_SIGNATURE')
    endpoint_secret = settings.STRIPE_WEBHOOK_SECRET
    
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, endpoint_secret
        )
    except ValueError:
        return JsonResponse({'error': 'Invalid payload'}, status=400)
    except stripe.error.SignatureVerificationError:
        return JsonResponse({'error': 'Invalid signature'}, status=400)
    
    if event['type'] == 'payment_intent.succeeded':
        payment_intent = event['data']['object']
        booking_id = payment_intent['metadata']['booking_id']
        
        try:
            booking = Booking.objects.get(id=booking_id)
            booking.payment_status = 'completed'
            booking.is_confirmed = True
            booking.status = 'confirmed'
            booking.payment_completed_at = timezone.now()
            booking.payment_method = payment_intent.get('payment_method_types', ['card'])[0]
            booking.save()
            
            # Send confirmation email
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
                    
                    # Send confirmation email
                    send_booking_confirmation_email(booking)
                    
                except Booking.DoesNotExist:
                    pass
        
        return JsonResponse({'status': 'success'})
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=400)

def send_booking_confirmation_email(booking):
    """Send booking confirmation email"""
    subject = f'Booking Confirmation - {booking.booking_reference}'
    
    # Text content
    text_content = render_to_string('emails/booking_confirmation.txt', {
        'booking': booking,
        'session': booking.session,
    })
    
    # HTML content
    html_content = render_to_string('emails/booking_confirmation.html', {
        'booking': booking,
        'session': booking.session,
    })
    
    email = EmailMultiAlternatives(
        subject=subject,
        body=text_content,
        from_email=settings.DEFAULT_FROM_EMAIL,
        to=[booking.customer_email]
    )
    email.attach_alternative(html_content, "text/html")
    
    try:
        email.send()
    except Exception as e:
        print(f"Email sending failed: {e}")

def send_cash_payment_confirmation_email(booking):
    """Send cash payment booking confirmation email"""
    subject = f'Booking Confirmed - Pay at Event - {booking.booking_reference}'
    
    # Text content
    text_content = f"""
    Your booking has been confirmed!
    
    Booking Reference: {booking.booking_reference}
    Session: {booking.session.name}
    Date: {booking.session.date}
    Time: {booking.session.start_time} - {booking.session.end_time}
    Participants: {booking.participants}
    Total Amount: €{booking.total_price}
    
    PAYMENT METHOD: Cash at Event
    
    Please bring €{booking.total_price} in cash when you arrive at the event.
    Show this booking reference to complete your payment: {booking.booking_reference}
    
    Thank you for your booking!
    """
    
    # HTML content
    html_content = render_to_string('emails/cash_booking_confirmation.html', {
        'booking': booking,
        'session': booking.session,
    })
    
    email = EmailMultiAlternatives(
        subject=subject,
        body=text_content,
        from_email=settings.DEFAULT_FROM_EMAIL,
        to=[booking.customer_email]
    )
    email.attach_alternative(html_content, "text/html")
    
    try:
        email.send()
    except Exception as e:
        print(f"Email sending failed: {e}")