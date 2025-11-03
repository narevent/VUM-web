# company/context_processors.py
"""
Context processors to make data available across all templates.
Add this file to your company app directory.
"""

from .models import CompanyInfo, ContactInfo


def company_context(request):
    """
    Makes company and contact information available to all templates.
    
    Usage in settings.py:
    TEMPLATES = [
        {
            ...
            'OPTIONS': {
                'context_processors': [
                    ...
                    'company.context_processors.company_context',
                ],
            },
        },
    ]
    """
    try:
        company_info = CompanyInfo.objects.first()
    except:
        company_info = None
    
    try:
        contact_info = ContactInfo.objects.first()
    except:
        contact_info = None
    
    return {
        'company_info': company_info,
        'contact_info': contact_info,
    }