# company/models.py
from django.db import models
from django.utils.translation import gettext_lazy as _
from parler.models import TranslatableModel, TranslatedFields

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
    address = models.CharField(max_length=64)
    postal_code = models.CharField(max_length=6)
    city = models.CharField(max_length=64)
    email = models.EmailField()
    phone = models.CharField(max_length=10, blank=True, null=True)

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

    def __str__(self):
        return self.name


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
    