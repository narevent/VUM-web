"""
Complete translation command for all apps:
- company (CompanyInfo, FAQ)
- events (GameSession)
- games (Instrument, GameTitle)
- sections (Header, Banner, Story, Principle, Stat)
"""

import time
from googletrans import Translator
from django.core.management.base import BaseCommand
from django.db import transaction

# Import all translatable models
from company.models import CompanyInfo, FAQ
from events.models import GameSession
from games.models import Instrument, GameTitle
from sections.models import Header, Banner, Story, Principle, Stat


class Command(BaseCommand):
    help = 'Translate all English content to Croatian using Google Translate'

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Overwrite existing Croatian translations',
        )
        parser.add_argument(
            '--app',
            type=str,
            help='Translate only specific app (company, events, games, sections)',
        )

    def handle(self, *args, **options):
        translator = Translator()
        force = options['force']
        app_filter = options.get('app')
        
        self.stdout.write(self.style.WARNING('='*60))
        self.stdout.write(self.style.WARNING('Starting Croatian Translation'))
        self.stdout.write(self.style.WARNING('='*60))
        
        stats = {
            'translated': 0,
            'skipped': 0,
            'errors': 0
        }
        
        # Company App
        if not app_filter or app_filter == 'company':
            self.stdout.write(self.style.SUCCESS('\n📦 COMPANY APP'))
            stats = self.translate_company_info(translator, force, stats)
            stats = self.translate_faqs(translator, force, stats)
        
        # Events App
        if not app_filter or app_filter == 'events':
            self.stdout.write(self.style.SUCCESS('\n📅 EVENTS APP'))
            stats = self.translate_game_sessions(translator, force, stats)
        
        # Games App
        if not app_filter or app_filter == 'games':
            self.stdout.write(self.style.SUCCESS('\n🎮 GAMES APP'))
            stats = self.translate_instruments(translator, force, stats)
            stats = self.translate_game_titles(translator, force, stats)
        
        # Sections App
        if not app_filter or app_filter == 'sections':
            self.stdout.write(self.style.SUCCESS('\n📄 SECTIONS APP'))
            stats = self.translate_headers(translator, force, stats)
            stats = self.translate_banners(translator, force, stats)
            stats = self.translate_stories(translator, force, stats)
            stats = self.translate_principles(translator, force, stats)
            stats = self.translate_stats(translator, force, stats)
        
        # Final summary
        self.stdout.write('')
        self.stdout.write(self.style.SUCCESS('='*60))
        self.stdout.write(self.style.SUCCESS('🎉 TRANSLATION COMPLETE!'))
        self.stdout.write(self.style.SUCCESS('='*60))
        self.stdout.write(self.style.SUCCESS(f'✓ Translated: {stats["translated"]}'))
        if stats['skipped'] > 0:
            self.stdout.write(self.style.WARNING(f'⊘ Skipped: {stats["skipped"]} (use --force to overwrite)'))
        if stats['errors'] > 0:
            self.stdout.write(self.style.ERROR(f'✗ Errors: {stats["errors"]}'))
        self.stdout.write(self.style.SUCCESS('='*60))

    def translate_field(self, translator, text, delay=1):
        """Translate a single field with error handling"""
        if not text or text.strip() == '':
            return None
        try:
            result = translator.translate(text, src='en', dest='hr').text
            time.sleep(delay)
            return result
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'    Translation error: {e}'))
            return None

    def should_translate(self, obj, force):
        """Check if object needs translation"""
        obj.set_current_language('hr')
        # Check if any translated field has content
        try:
            # Try to access any translated field to see if Croatian exists
            for field in obj.get_translated_fields():
                if getattr(obj, field, None):
                    return force  # Has Croatian, only translate if forced
            return True  # No Croatian content
        except:
            return True  # No Croatian content

    def translate_company_info(self, translator, force, stats):
        """Translate CompanyInfo"""
        self.stdout.write('  Translating CompanyInfo...')
        try:
            info = CompanyInfo.objects.first()
            if info:
                if self.should_translate(info, force):
                    info.set_current_language('en')
                    
                    about_hr = self.translate_field(translator, info.about_us)
                    mission_hr = self.translate_field(translator, info.mission)
                    vision_hr = self.translate_field(translator, info.vision)
                    
                    if about_hr and mission_hr and vision_hr:
                        info.set_current_language('hr', initialize=True)
                        info.about_us = about_hr
                        info.mission = mission_hr
                        info.vision = vision_hr
                        info.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS('    ✓ CompanyInfo'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
                    self.stdout.write(self.style.WARNING('    ⊘ Already has Croatian'))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
            stats['errors'] += 1
        return stats

    def translate_faqs(self, translator, force, stats):
        """Translate FAQs"""
        self.stdout.write('  Translating FAQs...')
        for faq in FAQ.objects.all():
            try:
                if self.should_translate(faq, force):
                    faq.set_current_language('en')
                    
                    question_hr = self.translate_field(translator, faq.question)
                    answer_hr = self.translate_field(translator, faq.answer)
                    
                    if question_hr and answer_hr:
                        faq.set_current_language('hr', initialize=True)
                        faq.question = question_hr
                        faq.answer = answer_hr
                        faq.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS(f'    ✓ FAQ: {faq.question[:40]}...'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
                stats['errors'] += 1
        return stats

    def translate_game_sessions(self, translator, force, stats):
        """Translate GameSessions"""
        self.stdout.write('  Translating GameSessions...')
        for session in GameSession.objects.all():
            try:
                if self.should_translate(session, force):
                    session.set_current_language('en')
                    
                    name_hr = self.translate_field(translator, session.name)
                    description_hr = self.translate_field(translator, session.description)
                    button_hr = self.translate_field(translator, session.button)
                    
                    if name_hr and description_hr:
                        session.set_current_language('hr', initialize=True)
                        session.name = name_hr
                        session.description = description_hr
                        if button_hr:
                            session.button = button_hr
                        session.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS(f'    ✓ Session: {session.name[:40]}...'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
                stats['errors'] += 1
        return stats

    def translate_instruments(self, translator, force, stats):
        """Translate Instruments"""
        self.stdout.write('  Translating Instruments...')
        for instrument in Instrument.objects.all():
            try:
                if self.should_translate(instrument, force):
                    instrument.set_current_language('en')
                    
                    name_hr = self.translate_field(translator, instrument.name)
                    description_hr = self.translate_field(translator, instrument.description)
                    
                    if name_hr and description_hr:
                        instrument.set_current_language('hr', initialize=True)
                        instrument.name = name_hr
                        instrument.description = description_hr
                        instrument.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS(f'    ✓ Instrument: {instrument.name[:40]}...'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
                stats['errors'] += 1
        return stats

    def translate_game_titles(self, translator, force, stats):
        """Translate GameTitles"""
        self.stdout.write('  Translating GameTitles...')
        for game in GameTitle.objects.all():
            try:
                if self.should_translate(game, force):
                    game.set_current_language('en')
                    
                    # Note: title is NOT translatable in GameTitle model
                    description_hr = self.translate_field(translator, game.description)
                    
                    if description_hr:
                        game.set_current_language('hr', initialize=True)
                        game.description = description_hr
                        game.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS(f'    ✓ Game: {game.title[:40]}...'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
                stats['errors'] += 1
        return stats

    def translate_headers(self, translator, force, stats):
        """Translate Headers"""
        self.stdout.write('  Translating Headers...')
        for header in Header.objects.all():
            try:
                if self.should_translate(header, force):
                    header.set_current_language('en')
                    
                    title_hr = self.translate_field(translator, header.title)
                    content_hr = self.translate_field(translator, header.content)
                    button1_hr = self.translate_field(translator, header.button1)
                    button2_hr = self.translate_field(translator, header.button2)
                    
                    if title_hr and content_hr:
                        header.set_current_language('hr', initialize=True)
                        header.title = title_hr
                        header.content = content_hr
                        if button1_hr:
                            header.button1 = button1_hr
                        if button2_hr:
                            header.button2 = button2_hr
                        header.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS(f'    ✓ Header: {header.title[:40]}...'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
                stats['errors'] += 1
        return stats

    def translate_banners(self, translator, force, stats):
        """Translate Banners"""
        self.stdout.write('  Translating Banners...')
        for banner in Banner.objects.all():
            try:
                if self.should_translate(banner, force):
                    banner.set_current_language('en')
                    
                    title_hr = self.translate_field(translator, banner.title)
                    content_hr = self.translate_field(translator, banner.content)
                    button1_hr = self.translate_field(translator, banner.button1)
                    button2_hr = self.translate_field(translator, banner.button2)
                    
                    if title_hr and content_hr:
                        banner.set_current_language('hr', initialize=True)
                        banner.title = title_hr
                        banner.content = content_hr
                        if button1_hr:
                            banner.button1 = button1_hr
                        if button2_hr:
                            banner.button2 = button2_hr
                        banner.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS(f'    ✓ Banner: {banner.title[:40]}...'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
                stats['errors'] += 1
        return stats

    def translate_stories(self, translator, force, stats):
        """Translate Stories"""
        self.stdout.write('  Translating Stories...')
        for story in Story.objects.all():
            try:
                if self.should_translate(story, force):
                    story.set_current_language('en')
                    
                    title_hr = self.translate_field(translator, story.title)
                    content_hr = self.translate_field(translator, story.content)
                    
                    if title_hr and content_hr:
                        story.set_current_language('hr', initialize=True)
                        story.title = title_hr
                        story.content = content_hr
                        story.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS(f'    ✓ Story: {story.title[:40]}...'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
                stats['errors'] += 1
        return stats

    def translate_principles(self, translator, force, stats):
        """Translate Principles"""
        self.stdout.write('  Translating Principles...')
        for principle in Principle.objects.all():
            try:
                if self.should_translate(principle, force):
                    principle.set_current_language('en')
                    
                    title_hr = self.translate_field(translator, principle.title)
                    content_hr = self.translate_field(translator, principle.content)
                    
                    if title_hr and content_hr:
                        principle.set_current_language('hr', initialize=True)
                        principle.title = title_hr
                        principle.content = content_hr
                        principle.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS(f'    ✓ Principle: {principle.title[:40]}...'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
                stats['errors'] += 1
        return stats

    def translate_stats(self, translator, force, stats):
        """Translate Stats"""
        self.stdout.write('  Translating Stats...')
        for stat in Stat.objects.all():
            try:
                if self.should_translate(stat, force):
                    stat.set_current_language('en')
                    
                    name_hr = self.translate_field(translator, stat.name)
                    
                    if name_hr:
                        stat.set_current_language('hr', initialize=True)
                        stat.name = name_hr
                        stat.save()
                        stats['translated'] += 1
                        self.stdout.write(self.style.SUCCESS(f'    ✓ Stat: {stat.name[:40]}...'))
                    else:
                        stats['errors'] += 1
                else:
                    stats['skipped'] += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'    ✗ Error: {e}'))
                stats['errors'] += 1
        return stats