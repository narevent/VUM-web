from django.urls import path
from . import views

urlpatterns = [
    path('sessions/', views.sessions_list, name='sessions_list'),
    path('book/<int:session_id>/', views.book_session, name='book_session'),
    path('booking-success/<uuid:access_token>/', views.booking_success, name='booking_success'),
    path('payment/<uuid:access_token>/', views.payment, name='payment'),
    path('api/availability/<int:session_id>/', views.check_availability, name='check_availability'),
    path('stripe/webhook/', views.stripe_webhook, name='stripe_webhook'), 
    path('paypal/webhook/', views.paypal_webhook, name='paypal_webhook'), # https://vumgames.com/games/paypal/webhook/
]