from django.db import models
from parler.models import TranslatableModel, TranslatedFields

class Header(TranslatableModel):
    translations = TranslatedFields(
        title=models.CharField(max_length=255),
        content=models.TextField(),
        button1=models.CharField(max_length=32, blank=True, null=True),
        button2=models.CharField(max_length=32, blank=True, null=True),
    )
    page = models.CharField(max_length=32, blank=True)
    image = models.ImageField(upload_to='headers', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["page"]

    def __str__(self):
        return self.safe_translation_getter("title", any_language=True)
    
class Banner(TranslatableModel):
    translations = TranslatedFields(
        title=models.CharField(max_length=255),
        content=models.TextField(),
        button1=models.CharField(max_length=32, blank=True, null=True),
        button2=models.CharField(max_length=32, blank=True, null=True),
    )
    page = models.CharField(max_length=32, blank=True)
    image = models.ImageField(upload_to='banners', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["order"]

    def __str__(self):
        return self.safe_translation_getter("title", any_language=True)

class Story(TranslatableModel):
    translations = TranslatedFields(
        title=models.CharField(max_length=255),
        content=models.TextField(),
    )
    icon = models.CharField(
        max_length=50,
        blank=True,
        help_text="Use an icon class (e.g., 'fa fa-star') for FontAwesome or similar."
    )
    created_at = models.DateTimeField(auto_now_add=True)
    order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["order"]
        verbose_name_plural = 'Stories'

    def __str__(self):
        return self.safe_translation_getter("title", any_language=True)
    
class Principle(TranslatableModel):
    translations = TranslatedFields(
        title=models.CharField(max_length=255),
        content=models.TextField(),
    )
    page = models.CharField(max_length=32, blank=True)
    icon = models.CharField(
        max_length=50,
        blank=True,
        help_text="Use an icon class (e.g., 'fa fa-star') for FontAwesome or similar."
    )
    order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return self.safe_translation_getter("title", any_language=True)
    

class Stat(TranslatableModel):
    translations = TranslatedFields(
        name=models.CharField(max_length=255),
    )
    count = models.PositiveIntegerField()
    order = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["order"]

    def __str__(self):
        return self.safe_translation_getter("name", any_language=True)