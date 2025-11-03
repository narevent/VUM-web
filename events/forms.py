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
                'placeholder': 'Full Name'
            }),
            'customer_email': forms.EmailInput(attrs={
                'class': 'form-control',
                'placeholder': 'email@example.com'
            }),
            'customer_phone': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': '+385 6 1234 5678'
            }),
            'participants': forms.NumberInput(attrs={
                'class': 'form-control',
                'min': 1,
                'max': 10
            }),
            'special_requests': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 3,
                'placeholder': 'Any special requests or requirements?'
            })
        }
    
    def __init__(self, *args, session=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.session = session
        if session:
            self.fields['participants'].widget.attrs['max'] = session.available_spots
    
    def clean_participants(self):
        participants = self.cleaned_data['participants']
        if self.session and participants > self.session.available_spots:
            raise forms.ValidationError(
                f'Only {self.session.available_spots} spots available for this session.'
            )
        return participants
