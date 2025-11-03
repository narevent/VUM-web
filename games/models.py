from django.db import models
from parler.models import TranslatableModel, TranslatedFields

class Instrument(TranslatableModel):
    """Available instruments for gaming"""

    translations = TranslatedFields(
        name=models.CharField(max_length=100),
        description=models.TextField(),
    )

    image = models.ImageField(upload_to='instruments/', blank=True)
    is_available = models.BooleanField(default=True)
    
    def __str__(self):
        # Return the translated name or fallback to any available language
        return self.safe_translation_getter("name", any_language=True)

class GameTitle(TranslatableModel):
    """Individual games available"""
    translations = TranslatedFields(
        description=models.TextField(),
    )
    title = models.CharField(max_length=200)
    min_players = models.PositiveIntegerField(default=1)
    max_players = models.PositiveIntegerField(default=4)
    difficulty_level = models.CharField(
        max_length=20,
        choices=[
            ('easy', 'Easy'),
            ('medium', 'Medium'),
            ('hard', 'Hard'),
            ('expert', 'Expert')
        ],
        default='medium'
    )
    compatible_instruments = models.ManyToManyField(Instrument, blank=True)
    image = models.ImageField(upload_to='games/', blank=True)
    is_featured = models.BooleanField(default=False)
    
    def __str__(self):
        return self.title