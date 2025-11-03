from django.shortcuts import render, redirect
from django.contrib import messages
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone
from company.models import Employee, FAQ
from sections.models import Header, Banner, Stat, Story, Principle
from games.models import GameTitle, Instrument
from events.models import GameSession
from .forms import ContactForm

def home(request):
    """Homepage with featured content"""
    header = Header.objects.filter(page='home').first()
    banners = Banner.objects.filter(page='home')
    featured_games = GameTitle.objects.filter(is_featured=True)[:6]
    upcoming_sessions = GameSession.objects.filter(
        date__gte=timezone.now().date(),
        is_active=True
    ).order_by('date', 'start_time')[:3]
    
    context = {
        'header': header,
        'banners': banners,
        'featured_games': featured_games,
        'upcoming_sessions': upcoming_sessions,
        'instruments': Instrument.objects.filter(is_available=True)
    }
    return render(request, 'company/home.html', context)

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