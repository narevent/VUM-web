from django.db import migrations, models
import django.db.models.deletion
from decimal import Decimal


class Migration(migrations.Migration):

    dependencies = [
        ('events', '0010_alter_gamesession_max_participants'),
    ]

    operations = [
        migrations.CreateModel(
            name='DiscountCode',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('code', models.CharField(max_length=50, unique=True)),
                ('description', models.CharField(blank=True, help_text='Internal note about this code', max_length=200)),
                ('discount_type', models.CharField(
                    choices=[('percentage', 'Percentage (%)'), ('fixed', 'Fixed Amount (€)')],
                    default='percentage',
                    max_length=20,
                )),
                ('discount_value', models.DecimalField(
                    decimal_places=2,
                    max_digits=8,
                    help_text='Percentage (0–100) or fixed euro amount to deduct',
                )),
                ('max_uses', models.PositiveIntegerField(
                    blank=True,
                    null=True,
                    help_text='Maximum total uses. Leave blank for unlimited.',
                )),
                ('uses_count', models.PositiveIntegerField(default=0, editable=False)),
                ('valid_from', models.DateTimeField(
                    blank=True,
                    null=True,
                    help_text='Start of validity window (blank = no restriction)',
                )),
                ('valid_until', models.DateTimeField(
                    blank=True,
                    null=True,
                    help_text='End of validity window (blank = no expiry)',
                )),
                ('is_active', models.BooleanField(default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('applicable_events', models.ManyToManyField(
                    blank=True,
                    help_text='Restrict to specific events. Leave empty to apply to all events/sessions.',
                    related_name='discount_codes',
                    to='events.event',
                )),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddField(
            model_name='booking',
            name='discount_code',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='bookings',
                to='events.discountcode',
            ),
        ),
        migrations.AddField(
            model_name='booking',
            name='discount_amount',
            field=models.DecimalField(decimal_places=2, default=Decimal('0.00'), max_digits=8),
        ),
    ]
