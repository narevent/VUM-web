import time
from googletrans import Translator
from django.core.management.base import BaseCommand
from company.models import CompanyInfo, FAQ

class Command(BaseCommand):
    help = 'Translate all English content to Croatian using Google Translate'

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Overwrite existing Croatian translations',
        )

    def handle(self, *args, **options):
        translator = Translator()
        force = options['force']
        
        self.stdout.write(self.style.WARNING('Starting translation...'))
        
        # Translate CompanyInfo
        try:
            info = CompanyInfo.objects.first()
            if info:
                info.set_current_language('en')
                
                # Check if Croatian already exists
                info.set_current_language('hr')
                if force or not info.about_us:
                    info.set_current_language('en')
                    
                    self.stdout.write('Translating CompanyInfo...')
                    
                    # Translate each field
                    about_hr = translator.translate(info.about_us, src='en', dest='hr').text
                    time.sleep(1)  # Avoid rate limiting
                    
                    mission_hr = translator.translate(info.mission, src='en', dest='hr').text
                    time.sleep(1)
                    
                    vision_hr = translator.translate(info.vision, src='en', dest='hr').text
                    
                    # Save Croatian version
                    info.set_current_language('hr', initialize=True)
                    info.about_us = about_hr
                    info.mission = mission_hr
                    info.vision = vision_hr
                    info.save()
                    
                    self.stdout.write(self.style.SUCCESS('✓ CompanyInfo translated'))
                else:
                    self.stdout.write(self.style.WARNING('⊘ CompanyInfo already has Croatian (use --force to overwrite)'))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'✗ Error translating CompanyInfo: {e}'))
        
        # Translate FAQs
        faqs = FAQ.objects.all()
        translated = 0
        skipped = 0
        
        for faq in faqs:
            try:
                faq.set_current_language('en')
                question_en = faq.question
                answer_en = faq.answer
                
                # Check if Croatian already exists
                faq.set_current_language('hr')
                if force or not faq.question:
                    self.stdout.write(f'Translating: {question_en[:40]}...')
                    
                    question_hr = translator.translate(question_en, src='en', dest='hr').text
                    time.sleep(1)
                    
                    answer_hr = translator.translate(answer_en, src='en', dest='hr').text
                    time.sleep(1)
                    
                    faq.set_current_language('hr', initialize=True)
                    faq.question = question_hr
                    faq.answer = answer_hr
                    faq.save()
                    
                    translated += 1
                    self.stdout.write(self.style.SUCCESS(f'  ✓ Translated'))
                else:
                    skipped += 1
                    self.stdout.write(self.style.WARNING(f'  ⊘ Already has Croatian'))
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'  ✗ Error: {e}'))
        
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('='*50))
        self.stdout.write(self.style.SUCCESS(f'Translation complete!'))
        self.stdout.write(self.style.SUCCESS(f'FAQs translated: {translated}'))
        if skipped > 0:
            self.stdout.write(self.style.WARNING(f'FAQs skipped: {skipped} (use --force to overwrite)'))
        self.stdout.write(self.style.SUCCESS('='*50))