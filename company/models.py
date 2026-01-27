# company/models.py
from django.db import models
from django.utils.translation import gettext_lazy as _
from parler.models import TranslatableModel, TranslatedFields
from PIL import Image
from io import BytesIO
from django.core.files.uploadedfile import InMemoryUploadedFile
import sys

class CompanyInfo(TranslatableModel):
    translations = TranslatedFields(
        about_us=models.TextField(),
        mission=models.TextField(),
        vision=models.TextField(),
    )
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Company Information"
        verbose_name_plural = "Company Information"

    def __str__(self):
        return "Company Info"


class ContactInfo(models.Model):
    name = models.CharField(max_length=64)
    email = models.EmailField()

    class Meta:
        verbose_name = "Contact Information"
        verbose_name_plural = "Contact Information"

    def __str__(self):
        return self.name
    
    
class Employee(models.Model):
    name = models.CharField(max_length=64)
    role = models.CharField(max_length=64)
    description = models.CharField(max_length=64)
    social = models.URLField(blank=True)
    photo = models.ImageField(upload_to='employees/', blank=True, null=True)

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if self.photo:
            # Open the image
            img = Image.open(self.photo)
            
            # Convert to grayscale
            img = img.convert('L')
            
            # Scale down to a reasonable size (e.g., 400x400 max)
            max_size = (400, 400)
            img.thumbnail(max_size, Image.Resampling.LANCZOS)
            
            # Save the processed image
            output = BytesIO()
            img.save(output, format='PNG', quality=85)
            output.seek(0)
            
            # Replace the original file with processed one
            self.photo = InMemoryUploadedFile(
                output, 'ImageField', 
                f"{self.photo.name.split('.')[0]}_processed.png",
                'image/png', 
                sys.getsizeof(output), 
                None
            )
        
        super().save(*args, **kwargs)


class FAQ(TranslatableModel):
    translations = TranslatedFields(
        question=models.CharField(max_length=64),
        answer=models.TextField(),
    )
    order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ["order"]

    def __str__(self):
        return self.safe_translation_getter("question", any_language=True)


class Newsletter(models.Model):
    email = models.EmailField(unique=True)
    name = models.CharField(max_length=100, blank=True)
    subscribed_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = "Newsletter Subscription"
        verbose_name_plural = "Newsletter Subscriptions"
        ordering = ['-subscribed_at']

    def __str__(self):
        return self.email