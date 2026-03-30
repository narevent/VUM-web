from django import forms
from .models import Booking


class BookingForm(forms.ModelForm):
    class Meta:
        model = Booking
        fields = ['customer_name', 'customer_email', 'customer_phone',
                  'participants', 'special_requests']
        widgets = {
            'customer_name': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Full Name',
            }),
            'customer_email': forms.EmailInput(attrs={
                'class': 'form-control',
                'placeholder': 'email@example.com',
            }),
            'customer_phone': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': '+385 6 1234 5678',
            }),
            'participants': forms.NumberInput(attrs={
                'class': 'form-control',
                'min': 1,
                'max': 10,
            }),
            'special_requests': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 3,
                'placeholder': 'Any special requests or requirements?',
            }),
        }

    def __init__(self, *args, session=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.session = session

        if session and session.has_ticket_types:
            # participants is derived from ticket_type + ticket_quantity in
            # Booking.save(), so we don't need the user to supply it.
            # Make the field optional and set a safe default so ModelForm
            # validation passes; the real value is overwritten on save().
            self.fields['participants'].required = False
            self.fields['participants'].initial = 1
        elif session:
            # Legacy mode: cap the widget max at available spots
            self.fields['participants'].widget.attrs['max'] = session.available_spots

    def clean_participants(self):
        # Skip capacity validation when ticket-type pricing is active —
        # the view handles that check against (participant_count × quantity).
        if self.session and self.session.has_ticket_types:
            return self.cleaned_data.get('participants') or 1

        participants = self.cleaned_data.get('participants')
        if participants and self.session and participants > self.session.available_spots:
            raise forms.ValidationError(
                f'Only {self.session.available_spots} spots available for this session.'
            )
        return participants