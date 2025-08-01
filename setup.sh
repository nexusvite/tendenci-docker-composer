#!/bin/bash
set -e

# Activate virtual environment
# source /srv/venv_tendenci/bin/activate

echo "Starting Tendenci setup..."

# Wait for database to be ready
echo "Waiting for database to be ready..."
until pg_isready -h $DB_HOST -U $DB_USER; do
  echo "Waiting for database..."
  sleep 2
done

# Check if this is the first run
if [ ! -f "/var/www/mysite/conf/settings.py" ]; then
  echo "First run detected. Setting up Tendenci..."
  
  # Create Tendenci project
  tendenci startproject mysite
  cd /var/www/mysite
  
  # Create log directory
  mkdir -p /var/log/mysite
  
  # Copy juniper theme
  mkdir -p /var/www/mysite/themes/juniper
  cp -r /srv/venv_tendenci/lib/python*/site-packages/tendenci/themes/juniper/* /var/www/mysite/themes/juniper/
  
  # Create settings file with environment variables
  cat > /var/www/mysite/conf/settings.py << EOF
import os

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('SECRET_KEY', 'your-default-secret-key-change-in-production')

# SECURITY WARNING: keep the site settings key used in production secret!
SITE_SETTINGS_KEY = os.environ.get('SITE_SETTINGS_KEY', 'your-default-site-settings-key-change-in-production')

ALLOWED_HOSTS = ['*']

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'tendenci'),
        'USER': os.environ.get('DB_USER', 'tendenci'),
        'PASSWORD': os.environ.get('DB_PASS', 'tendenci'),
        'HOST': os.environ.get('DB_HOST', 'db'),
        'PORT': '5432',
    }
}

TIME_ZONE = 'UTC'

USE_TZ = True

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'DEBUG',
            'class': 'logging.FileHandler',
            'filename': '/var/log/mysite/debug.log',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'DEBUG',
            'propagate': True,
        },
    },
}

# Media files
MEDIA_ROOT = '/var/www/mysite/media/'
MEDIA_URL = '/media/'

# Static files
STATIC_ROOT = '/var/www/mysite/static/'
STATIC_URL = '/static/'

# Theme directory
THEMES_DIR = '/var/www/mysite/themes/'

# Whoosh index
HAYSTACK_CONNECTIONS = {
    'default': {
        'ENGINE': 'haystack.backends.whoosh_backend.WhooshEngine',
        'PATH': '/var/www/mysite/whoosh_index',
    },
}
EOF

  # Set permissions
  chmod -R -x+X /var/www/mysite/media/
  chown -R tendenci: /var/log/mysite
  
  # Initialize database
  echo "Initializing database..."
  python manage.py initial_migrate
  python manage.py deploy
  python manage.py load_tendenci_defaults
  python manage.py update_dashboard_stats
  python manage.py rebuild_index --noinput
  
  # Set site URL
  python manage.py set_setting site global siteurl 'http://localhost:8080'
  
  echo "Tendenci setup completed!"
else
  echo "Tendenci already set up. Running any pending migrations..."
  cd /var/www/mysite
  python manage.py migrate
  python manage.py deploy
  echo "Updates completed!"
fi

echo "Setup process finished."