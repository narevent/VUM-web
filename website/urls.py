from django.contrib import admin
from django.conf.urls.i18n import i18n_patterns, set_language
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.utils.translation import gettext_lazy as _
import events.views as event_views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('stripe/webhook/', event_views.stripe_webhook, name='stripe_webhook'), 
    path('paypal/webhook/', event_views.paypal_webhook, name='paypal_webhook'), # https://vumgames.com/games/paypal/webhook/
]

urlpatterns += [
    path('set-language/', set_language, name='set_language'),
]

urlpatterns += i18n_patterns(
    path('', include('company.urls')),
    path('', include('events.urls')),
    path('playground/', include('playground.urls')),
)

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)