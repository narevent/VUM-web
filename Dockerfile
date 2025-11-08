FROM python:3.11-slim

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV DJANGO_SETTINGS_MODULE=website.settings.production

# Configure DNS64 for IPv6-only networks
RUN echo "nameserver 2001:4860:4860::8888" > /etc/resolv.conf && \
    echo "nameserver 2001:4860:4860::8844" >> /etc/resolv.conf

# Set work directory
WORKDIR /app

# Install system dependencies with better error handling
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir gunicorn

# Copy project
COPY . .

# Copy environment file for build process
COPY .env.production .env.production

# Create necessary directories
RUN mkdir -p /app/staticfiles /app/media

# Collect static files (now it can read .env.production)
RUN python manage.py collectstatic --noinput

# Create a non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Run gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "--timeout", "60", "website.wsgi:application"]