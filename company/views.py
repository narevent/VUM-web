from django.shortcuts import render, redirect
from django.contrib import messages
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone
from django.http import JsonResponse
from company.models import Employee, FAQ
from sections.models import Header, Banner, Stat, Story, Principle
from games.models import GameTitle, Instrument
from events.models import GameSession
from .forms import ContactForm, NewsletterForm

def home(request):
    """Homepage with featured content"""
    header = Header.objects.filter(page='home').first()
    banners = Banner.objects.filter(page='home')
    featured_games = GameTitle.objects.filter(is_featured=True)[:6]
    upcoming_sessions = GameSession.objects.filter(
        date__gte=timezone.now().date(),
        is_active=True
    ).order_by('date', 'start_time')[:3]
    
    # Handle newsletter subscription
    newsletter_form = NewsletterForm()
    
    context = {
        'header': header,
        'banners': banners,
        'featured_games': featured_games,
        'upcoming_sessions': upcoming_sessions,
        'instruments': Instrument.objects.filter(is_available=True),
        'newsletter_form': newsletter_form,
    }
    return render(request, 'company/home.html', context)


def newsletter_subscribe(request):
    """Handle newsletter subscription via AJAX"""
    if request.method == 'POST':
        form = NewsletterForm(request.POST)
        if form.is_valid():
            subscription = form.save()
            
            # Send confirmation email
            try:
                send_mail(
                    'Welcome to VUM Games Newsletter!',
                    f'Hi {subscription.name or "there"}!\n\n'
                    f'Thank you for subscribing to our newsletter. '
                    f'You\'ll now receive updates about new gaming sessions, events, and more!\n\n'
                    f'Stay tuned!\n'
                    f'The VUM Games Team',
                    settings.DEFAULT_FROM_EMAIL,
                    [subscription.email],
                    fail_silently=True,
                )
            except Exception as e:
                print(f"Error sending confirmation email: {e}")
            
            if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return JsonResponse({
                    'success': True,
                    'message': 'Thank you for subscribing! Check your email for confirmation.'
                })
            else:
                messages.success(request, 'Thank you for subscribing! Check your email for confirmation.')
                return redirect('home')
        else:
            if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
                return JsonResponse({
                    'success': False,
                    'errors': form.errors
                }, status=400)
            else:
                messages.error(request, 'Please correct the errors below.')
                return redirect('home')
    
    return redirect('home')


def about(request):
    """About page"""
    members = Employee.objects.all()
    stats = Stat.objects.all()
    stories = Story.objects.all()
    principles = Principle.objects.all()
    banners = Banner.objects.filter(page='about')
    header = Header.objects.filter(page='about').first()
    context = {
        'team_members': members,
        'stats': stats,
        'stories': stories,
        'principles': principles,
        'banners': banners,
        'header': header,
    }
    return render(request, 'company/about.html', context)


def contact(request):
    """Contact page with form"""
    if request.method == 'POST':
        form = ContactForm(request.POST)
        if form.is_valid():
            # Send email
            subject = f"Contact Form: {form.cleaned_data['subject']}"
            message = f"""
            New contact form submission:
            
            Name: {form.cleaned_data['name']}
            Email: {form.cleaned_data['email']}
            Subject: {form.cleaned_data['subject']}
            
            Message:
            {form.cleaned_data['message']}
            """
            
            try:
                send_mail(
                    subject,
                    message,
                    form.cleaned_data['email'],
                    [settings.DEFAULT_FROM_EMAIL],
                    fail_silently=False,
                )
                messages.success(request, 'Thank you! Your message has been sent.')
                return redirect('contact')
            except Exception as e:
                messages.error(request, 'Sorry, there was an error sending your message. Please try again.')
    else:
        form = ContactForm()
    
    context = {
        'header': Header.objects.filter(page='contact').first(),
        'banners': Banner.objects.filter(page='contact').all(),
        'faqs': FAQ.objects.all()[:5],
        'form': form,
    }
    return render(request, 'company/contact.html', context)