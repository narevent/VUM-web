from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone
from datetime import datetime, timedelta, time
from events.models import GameSession

'''
python3 manage.py create_gamesessions \
    --name 'VUM Gaming @ Atomic Bunker' \
    --description 'Join our big event this autumn in the Atomic Bunker in Zagreb!' \
    --game_type mixed \
    --start_date 2025-11-17 \
    --end_date 2025-11-22 \
    --start_time 12:00 \
    --end_time 20:00 \
    --price 5.00 \
    --max_participants 20
'''

class Command(BaseCommand):
    help = "Bulk create GameSessions between a start and end date"

    def add_arguments(self, parser):
        parser.add_argument("--name", type=str, required=True, help="Name for the game session")
        parser.add_argument("--description", type=str, default="", help="Description of the session")
        parser.add_argument("--game_type", type=str, default="mixed", choices=[g[0] for g in GameSession.GAME_TYPES])
        parser.add_argument("--start_date", type=str, required=True, help="Start date (YYYY-MM-DD)")
        parser.add_argument("--end_date", type=str, required=True, help="End date (YYYY-MM-DD)")
        parser.add_argument("--start_time", type=str, required=True, help="Start time (HH:MM)")
        parser.add_argument("--end_time", type=str, required=True, help="End time (HH:MM)")
        parser.add_argument("--price", type=float, required=True, help="Price per person")
        parser.add_argument("--max_participants", type=int, default=8, help="Maximum number of participants")

    def handle(self, *args, **options):
        try:
            start_date = datetime.strptime(options["start_date"], "%Y-%m-%d").date()
            end_date = datetime.strptime(options["end_date"], "%Y-%m-%d").date()
            start_time = datetime.strptime(options["start_time"], "%H:%M").time()
            end_time = datetime.strptime(options["end_time"], "%H:%M").time()
        except ValueError as e:
            raise CommandError(f"Invalid date/time format: {e}")

        if end_date < start_date:
            raise CommandError("End date must be after start date")

        delta = (end_date - start_date).days + 1
        sessions_to_create = []

        for i in range(delta):
            date = start_date + timedelta(days=i)
            # skip duplicates (if same date/time exists)
            if GameSession.objects.filter(date=date, start_time=start_time).exists():
                self.stdout.write(self.style.WARNING(f"Skipping {date} - already exists"))
                continue

            session = GameSession(
                name=options["name"],
                description=options["description"],
                game_type=options["game_type"],
                date=date,
                start_time=start_time,
                end_time=end_time,
                max_participants=options["max_participants"],
                price_per_person=options["price"],
                is_active=True,
            )
            sessions_to_create.append(session)

        if not sessions_to_create:
            self.stdout.write(self.style.WARNING("No new sessions to create."))
            return

        GameSession.objects.bulk_create(sessions_to_create)
        self.stdout.write(self.style.SUCCESS(f"✅ Created {len(sessions_to_create)} game sessions successfully!"))