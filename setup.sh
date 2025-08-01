#!/bin/bash
set -e

echo "Starting Tendenci setup..."

# Wait for the database to be ready
echo "Waiting for database to be ready..."
until pg_isready -h "$DB_HOST" -U "$DB_USER"; do
  echo "Waiting for database..."
  sleep 2
done

# Fix permissions
echo "Fixing permissions on mounted volumes..."
sudo chown -R tendenci: /var/www/

cd /var/www/mysite

# Create log directory if not exists
sudo mkdir -p /var/log/mysite
sudo chown -R tendenci: /var/log/mysite
sudo chown -R tendenci: /var/www/mysite/media/

# Only create settings.py if missing
if [ ! -f "/var/log/mysite/conf/settings.py" ]; then
  echo "conf/settings.py not found. Creating it..."
  mkdir -p conf
  cat > /var/log/mysite/conf/settings.py << EOF
import os

DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'
SECRET_KEY = os.environ.get('SECRET_KEY', 'your-default-secret-key-change-in-production')
SITE_SETTINGS_KEY = os.environ.get('SITE_SETTINGS_KEY', 'your-default-site-settings-key-change-in-production')

ALLOWED_HOSTS = ['*']

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

MEDIA_ROOT = '/var/www/mysite/media/'
MEDIA_URL = '/media/'

STATIC_ROOT = '/var/www/mysite/static/'
STATIC_URL = '/static/'

THEMES_DIR = '/var/www/mysite/themes/'

HAYSTACK_CONNECTIONS = {
    'default': {
        'ENGINE': 'haystack.backends.whoosh_backend.WhooshEngine',
        'PATH': '/var/www/mysite/whoosh_index',
    },
}
EOF
fi

# Copy Juniper theme if not already there
THEME_DIR="/var/www/mysite/themes/juniper"
if [ ! -d "$THEME_DIR" ]; then
  echo "Copying Juniper theme..."
  mkdir -p "$THEME_DIR"
  TENDENCI_PATH=$(python -c "import tendenci, os; print(os.path.dirname(tendenci.__file__))")
  cp -r "$TENDENCI_PATH/themes/juniper/"* "$THEME_DIR/" || echo "Juniper theme not found."
fi

# Set permissions
chmod -R 755 media/ themes/

# Run database setup commands
if [ -f "manage.py" ]; then
  echo "Applying migrations and setup commands..."
  python manage.py migrate
  python manage.py deploy
  python manage.py load_tendenci_defaults
  python manage.py update_dashboard_stats
  python manage.py rebuild_index --noinput
  python manage.py set_setting site global siteurl 'http://localhost:8082'
  echo "Tendenci setup completed!"
else
  echo "Error: manage.py not found. Cannot continue."
  exit 1
fi

echo "Setup process finished."
