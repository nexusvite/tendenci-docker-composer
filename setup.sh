#!/bin/bash
set -e

echo "Starting Tendenci setup..."

# Wait for database to be ready
echo "Waiting for database to be ready..."
until pg_isready -h "$DB_HOST" -U "$DB_USER"; do
  echo "Waiting for database..."
  sleep 2
done

# Fix permissions on mounted volumes
echo "Fixing permissions on mounted volumes..."
sudo chown -R tendenci: /var/www/

# Check if this is the first run
if [ ! -f "/var/www/mysite/conf/settings.py" ]; then
  echo "First run detected. Setting up Tendenci..."
  echo pwd
  echo "Creating Tendenci project..."
  cd /var/www/
  echo pwd
  tendenci startproject mysite

  # # Create Tendenci project if needed
  # if [ -f "/var/www/mysite/manage.py" ]; then
  #   echo "Creating Tendenci project..."
  #   cd /var/www/
  #   tendenci startproject mysite
  # elif [ -z "$(ls -A /var/www/mysite)" ]; then
  #   echo "mysite directory exists but is empty. Creating Tendenci project..."
  #   # cd /var/www/
  #   tendenci startproject mysite
  # else
  #   echo "mysite directory already exists and is not empty. Skipping project creation."
  # fi

  # Rescue nested manage.py if needed
  # if [ -f "/var/www/mysite/manage.py" ]; then
  #   echo "Fixing nested manage.py..."
  #   mv /var/www/mysite/mysite/manage.py /var/www/mysite/
  # fi

  cd /var/www/mysite

  # Create log directory
  sudo mkdir -p /var/log/mysite
  sudo chown -R tendenci: /var/log/mysite
  sudo chown -R tendenci: /var/www/mysite/media/

  # Copy juniper theme
  echo "Copying juniper theme..."
  mkdir -p /var/www/mysite/themes/juniper
  TENDENCI_PATH=$(python -c "import tendenci, os; print(os.path.dirname(tendenci.__file__))")
  if [ -d "$TENDENCI_PATH/themes/juniper" ]; then
    cp -r "$TENDENCI_PATH/themes/juniper/"* /var/www/mysite/themes/juniper/
  else
    echo "Warning: Juniper theme not found in $TENDENCI_PATH/themes/"
  fi

  # Create conf directory and settings
  echo "Creating conf/settings.py..."
  mkdir -p /var/www/mysite/conf
  cat > /var/www/mysite/conf/settings.py << EOF
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

  # Set permissions
  echo "Setting permissions..."
  chmod -R 755 /var/www/mysite/media/
  chmod -R 755 /var/www/mysite/themes/

  # Run initial migrations and setup
  if [ -f "manage.py" ]; then
    echo "Initializing database..."
    python manage.py migrate
    python manage.py deploy
    python manage.py load_tendenci_defaults
    python manage.py update_dashboard_stats
    python manage.py rebuild_index --noinput
    python manage.py set_setting site global siteurl 'http://localhost:8082'
    echo "Tendenci setup completed!"
  else
    echo "Error: manage.py not found even after rescue. Setup failed."
    exit 1
  fi
else
  echo "Tendenci already set up. Running pending migrations..."
  cd /var/www/mysite
  if [ -f "manage.py" ]; then
    python manage.py migrate
    python manage.py deploy
    echo "Updates completed!"
  else
    echo "Error: manage.py not found in existing setup."
    exit 1
  fi
fi

echo "Setup process finished."
