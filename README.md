# VumGames Website

Django-based website for VumGames, deployed on Debian 13 VPS with HTTPS.

## 🚀 Quick Start

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/narevent/VUM-web.git
   cd VUM-web
   ```

2. **Create virtual environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Create .env file**
   ```bash
   cp .env.example .env
   # Edit .env and set DEBUG=True for local development
   ```

5. **Run migrations**
   ```bash
   python manage.py migrate
   ```

6. **Create superuser**
   ```bash
   python manage.py createsuperuser
   ```

7. **Run development server**
   ```bash
   python manage.py runserver
   ```

   Visit: http://localhost:8000

## 🌐 Production Deployment

### Prerequisites
- Debian 13 VPS
- Domain: vumgames.com
- SSH access to VPS
- GitHub repository

### Step 1: Initial VPS Setup

```bash
# On VPS
git clone https://github.com/narevent/VUM-web.git /tmp/setup
cd /tmp/setup
bash scripts/init_vps.sh
```

### Step 2: Deploy Application

```bash
bash scripts/deploy.sh
```

Follow the prompts to:
- Confirm GitHub repository URL
- Create Django superuser (optional)
- Setup SSL certificate with Let's Encrypt

### Step 3: Configure Settings

Edit `/var/www/vumgames/.env` and configure:
- Email settings (if using email features)
- Stripe/PayPal credentials (if using payments)
- Any other sensitive settings

### Step 4: Restart Services

```bash
sudo systemctl restart gunicorn
sudo systemctl reload nginx
```

## 🔄 Updating the Site

When you push changes to GitHub:

```bash
# On VPS
cd /var/www/vumgames
bash scripts/update.sh
```

## 🛠️ Management Scripts

All scripts are in the `scripts/` directory:

- **init_vps.sh** - Initialize a fresh VPS
- **deploy.sh** - Initial deployment
- **update.sh** - Pull changes and update site
- **backup.sh** - Create backups of database and media
- **restore.sh** - Restore from backup
- **logs.sh** - View application logs

### Running Scripts

```bash
# Make scripts executable (first time only)
chmod +x scripts/*.sh

# Run any script
bash scripts/SCRIPT_NAME.sh
```

## 📦 Backups

### Create Backup

```bash
bash scripts/backup.sh
```

Backups are stored in `/var/backups/vumgames/`

### Restore from Backup

```bash
bash scripts/restore.sh
```

## 📊 Monitoring & Logs

### View Logs

```bash
bash scripts/logs.sh
```

Or manually:

```bash
# Gunicorn service logs
sudo journalctl -u gunicorn -f

# Application logs
sudo tail -f /var/www/vumgames/logs/gunicorn-error.log
sudo tail -f /var/www/vumgames/logs/gunicorn-access.log

# Nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### Check Service Status

```bash
sudo systemctl status gunicorn
sudo systemctl status nginx
```

### Restart Services

```bash
sudo systemctl restart gunicorn
sudo systemctl reload nginx
```

## 🌍 Languages

The site supports:
- Croatian (hr) - Default
- English (en)

### Managing Translations

```bash
# Create/update translation files
python manage.py makemessages -l hr
python manage.py makemessages -l en

# Compile translations
python manage.py compilemessages
```

## 🗂️ Project Structure

```
vumgames/
├── company/           # Company app
├── events/            # Events app
├── games/             # Games app
├── sections/          # Sections app
├── core/              # Core utilities and middleware
├── website/           # Main project settings
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── templates/         # HTML templates
├── static/            # Static files (CSS, JS, images)
├── media/             # User-uploaded files
├── locale/            # Translation files
├── db/                # SQLite database
├── scripts/           # Deployment scripts
├── manage.py
├── requirements.txt
└── .env              # Environment variables (not in git)
```

## 🔒 Security

- HTTPS enforced via Let's Encrypt
- Secrets stored in `.env` (never commit to git)
- CSRF protection enabled
- Secure cookies in production
- XSS protection headers
- Auto-renewal of SSL certificates

## 📱 Admin Panel

Access at: https://vumgames.com/admin/

## 🐛 Troubleshooting

### Site shows 502 Bad Gateway

```bash
# Check Gunicorn status
sudo systemctl status gunicorn

# Check logs
sudo journalctl -u gunicorn -n 50

# Restart Gunicorn
sudo systemctl restart gunicorn
```

### Static files not loading

```bash
cd /var/www/vumgames
sudo -u www-data venv/bin/python manage.py collectstatic --noinput
sudo systemctl reload nginx
```

### Database errors

```bash
cd /var/www/vumgames
sudo -u www-data venv/bin/python manage.py migrate
sudo systemctl restart gunicorn
```

### SSL certificate issues

```bash
# Check certificate status
sudo certbot certificates

# Renew certificate
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run
```

## 📞 Support

For issues, check:
1. Application logs: `bash scripts/logs.sh`
2. Service status: `sudo systemctl status gunicorn nginx`
3. Nginx config: `sudo nginx -t`
