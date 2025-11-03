from django.contrib import admin
from django.conf.urls.i18n import i18n_patterns, set_language
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.utils.translation import gettext_lazy as _

urlpatterns = [
    path('admin/', admin.site.urls),
]

urlpatterns += [
    path('set-language/', set_language, name='set_language'),
]

urlpatterns += i18n_patterns(
    path('', include('company.urls')),
    path('', include('events.urls')),
)

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)