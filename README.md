# VUM Games Website

A Django-based web platform for managing and showcasing gaming events and content.

## Project Structure

```
VUM-web/
├── company/          # Company information and management
├── core/             # Core application functionality
├── docker/           # Docker configuration files
├── events/           # Event management system
├── games/            # Games catalog and management
├── scripts/          # Utility scripts
├── sections/         # Website sections/pages
├── static/           # Static files (CSS, JS, images)
├── templates/        # HTML templates
├── website/          # Main website configuration
├── manage.py         # Django management script
├── requirements.txt  # Python dependencies
└── docker-compose.yaml  # Docker Compose configuration
```

## Technologies Used

- **Backend**: Python/Django
- **Containerization**: Docker & Docker Compose
- **Frontend**: HTML templates with static assets

## Prerequisites

- Python 3.x
- Docker and Docker Compose (for containerized deployment)
- pip (Python package manager)

## Installation

### Local Development

1. Clone the repository:
```bash
git clone https://github.com/narevent/VUM-web.git
cd VUM-web
```

2. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Set up environment variables:
```bash
cp .env.production.example .env
# Edit .env with your configuration
```

5. Run migrations:
```bash
python manage.py migrate
```

6. Create a superuser:
```bash
python manage.py createsuperuser
```

7. Run the development server:
```bash
python manage.py runserver
```

The application will be available at `http://localhost:8000`

### Docker Deployment

1. Clone the repository:
```bash
git clone https://github.com/narevent/VUM-web.git
cd VUM-web
```

2. Set up environment variables:
```bash
cp .env.production.example .env
# Edit .env with your production configuration
```

3. Build and run with Docker Compose:
```bash
docker-compose up -d
```

4. Run migrations inside the container:
```bash
docker-compose exec web python manage.py migrate
```

5. Create a superuser:
```bash
docker-compose exec web python manage.py createsuperuser
```

## Features

- **Events Management**: Create and manage gaming events
- **Games Catalog**: Maintain a database of games
- **Company Information**: Display company details and information
- **Sections System**: Modular website sections for flexible content management
- **Admin Interface**: Django admin panel for content management

## Configuration

The project uses environment variables for configuration. Copy `.env.production.example` to `.env` and configure the following:

- Database settings
- Secret key
- Debug mode
- Allowed hosts
- Static files configuration
- Other Django settings

## Development

### Running Migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

### Collecting Static Files

```bash
python manage.py collectstatic
```

### Running Tests

```bash
python manage.py test
```

## Project Modules

- **company**: Manages company-related information
- **events**: Handles event creation, management, and display
- **games**: Manages game catalog and related functionality
- **sections**: Provides modular content sections for the website
- **core**: Contains core application logic and utilities

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is maintained by narevent. Please check the repository for license information.

## Contact

For questions or support, please open an issue on the GitHub repository.

## Acknowledgments

- Built with Django
- Containerized with Docker