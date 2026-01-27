from django.contrib import admin
from parler.admin import TranslatableAdmin
from .models import CompanyInfo, ContactInfo, Employee, FAQ, Newsletter

from django.contrib import messages
from googletrans import Translator
import time

translator = Translator()


@admin.register(CompanyInfo)
class CompanyInfoAdmin(TranslatableAdmin):
    list_display = ['about_us', 'updated_at']
    list_filter = ['updated_at']
    search_fields = ['about_us', 'mission', 'vision']
    readonly_fields = ['updated_at']

    actions = ['auto_translate_to_croatian']
    
    def auto_translate_to_croatian(self, request, queryset):
        """Auto-translate English to Croatian"""
        try:
            for obj in queryset:
                obj.set_current_language('en')
                
                # Translate
                about_hr = translator.translate(obj.about_us, src='en', dest='hr').text
                time.sleep(1)
                mission_hr = translator.translate(obj.mission, src='en', dest='hr').text
                time.sleep(1)
                vision_hr = translator.translate(obj.vision, src='en', dest='hr').text
                
                # Save Croatian
                obj.set_current_language('hr', initialize=True)
                obj.about_us = about_hr
                obj.mission = mission_hr
                obj.vision = vision_hr
                obj.save()
            
            messages.success(request, f'✓ Translated {queryset.count()} item(s) to Croatian')
        except Exception as e:
            messages.error(request, f'✗ Translation error: {e}')
    
    auto_translate_to_croatian.short_description = "🇭🇷 Auto-translate to Croatian"


@admin.register(ContactInfo)
class ContactInfoAdmin(admin.ModelAdmin):
    list_display = ['name', 'email']
    list_filter = ['name']
    search_fields = ['name', 'email']
    readonly_fields = []


@admin.register(Employee)
class EmployeeAdmin(admin.ModelAdmin):
    list_display = ['name', 'role', 'social']
    list_filter = ['name', 'role']
    search_fields = ['name', 'role']
    readonly_fields = []


@admin.register(FAQ)
class FAQAdmin(TranslatableAdmin):
    list_display = ['question', 'order']
    list_filter = ['order']
    search_fields = ['question', 'answer']
    readonly_fields = []

    actions = ['auto_translate_to_croatian']
    
    def auto_translate_to_croatian(self, request, queryset):
        """Auto-translate English to Croatian"""
        try:
            for obj in queryset:
                obj.set_current_language('en')
                
                question_hr = translator.translate(obj.question, src='en', dest='hr').text
                time.sleep(1)
                answer_hr = translator.translate(obj.answer, src='en', dest='hr').text
                time.sleep(1)
                
                obj.set_current_language('hr', initialize=True)
                obj.question = question_hr
                obj.answer = answer_hr
                obj.save()
            
            messages.success(request, f'✓ Translated {queryset.count()} FAQ(s) to Croatian')
        except Exception as e:
            messages.error(request, f'✗ Translation error: {e}')
    
    auto_translate_to_croatian.short_description = "🇭🇷 Auto-translate to Croatian"


@admin.register(Newsletter)
class NewsletterAdmin(admin.ModelAdmin):
    list_display = ['email', 'name', 'subscribed_at', 'is_active']
    list_filter = ['is_active', 'subscribed_at']
    search_fields = ['email', 'name']
    readonly_fields = ['subscribed_at']
    date_hierarchy = 'subscribed_at'
    
    actions = [
        'activate_subscriptions', 
        'deactivate_subscriptions', 
        'export_as_csv',
        'send_welcome_email',
        'send_bulk_email'
    ]
    
    def activate_subscriptions(self, request, queryset):
        updated = queryset.update(is_active=True)
        self.message_user(request, f'✓ {updated} subscription(s) activated.')
    activate_subscriptions.short_description = '✅ Activate selected subscriptions'
    
    def deactivate_subscriptions(self, request, queryset):
        updated = queryset.update(is_active=False)
        self.message_user(request, f'✓ {updated} subscription(s) deactivated.')
    deactivate_subscriptions.short_description = '❌ Deactivate selected subscriptions'
    
    def export_as_csv(self, request, queryset):
        import csv
        from django.http import HttpResponse
        
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="newsletter_subscribers.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['Email', 'Name', 'Subscribed At', 'Is Active'])
        
        for subscription in queryset:
            writer.writerow([
                subscription.email,
                subscription.name,
                subscription.subscribed_at.strftime('%Y-%m-%d %H:%M:%S'),
                subscription.is_active
            ])
        
        return response
    export_as_csv.short_description = '📥 Export selected as CSV'
    
    def send_welcome_email(self, request, queryset):
        """Send welcome email to selected subscribers"""
        from django.core.mail import send_mail
        from django.conf import settings
        
        sent_count = 0
        failed_count = 0
        
        for subscription in queryset.filter(is_active=True):
            try:
                # English version
                subject_en = 'Welcome to VUM Games Newsletter!'
                message_en = f'''Hi {subscription.name or "there"}!

Thank you for subscribing to our newsletter.

You'll now receive updates about:
• New gaming sessions
• Special events
• Exclusive promotions
• Behind-the-scenes content

Stay tuned for exciting updates!

The VUM Games Team

---
To unsubscribe, please contact us at {settings.DEFAULT_FROM_EMAIL}
'''
                
                # Croatian version
                subject_hr = 'Dobrodošli u VUM Games Newsletter!'
                message_hr = f'''Bok {subscription.name or ""}!

Hvala što ste se pretplatili na naš newsletter.

Sada ćete primati obavijesti o:
• Novim gaming sesijama
• Posebnim događajima
• Ekskluzivnim promocijama
• Sadržaju iza kulisa

Ostanite s nama za uzbudljiva ažuriranja!

VUM Games Tim

---
Za odjavu, kontaktirajte nas na {settings.DEFAULT_FROM_EMAIL}
'''
                
                # Send both versions (you can choose one or use language preference)
                send_mail(
                    subject_en,
                    message_en,
                    settings.DEFAULT_FROM_EMAIL,
                    [subscription.email],
                    fail_silently=False,
                )
                
                sent_count += 1
                time.sleep(0.5)  # Rate limiting
                
            except Exception as e:
                failed_count += 1
                print(f"Error sending to {subscription.email}: {e}")
        
        if sent_count > 0:
            messages.success(request, f'✓ Sent {sent_count} welcome email(s)')
        if failed_count > 0:
            messages.warning(request, f'⚠ Failed to send {failed_count} email(s)')
    
    send_welcome_email.short_description = '📧 Send welcome email (EN)'
    
    def send_bulk_email(self, request, queryset):
        """Send custom bulk email to selected subscribers"""
        # This is a placeholder - you would integrate with a proper email service
        # For now, it just shows a message
        active_count = queryset.filter(is_active=True).count()
        messages.info(
            request, 
            f'📨 To send bulk emails to {active_count} subscriber(s), '
            f'please use a dedicated email marketing service like Mailchimp or SendGrid. '
            f'You can export the list as CSV and import it there.'
        )
    
    send_bulk_email.short_description = '📨 Bulk email info'