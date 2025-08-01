#!/bin/bash
set -e

echo "Starting Tendenci setup..."

# Wait for the database to be ready
echo "Waiting for database to be ready..."
until pg_isready -h "$DB_HOST" -U "$DB_USER"; do
  echo "Waiting for database..."
  sleep 2
done

# Fix permissions on volumes
echo "Fixing permissions on mounted volumes..."
sudo chown -R tendenci: /var/www/

cd /var/www/mysite

# Ensure log and media directories exist and have correct permissions
sudo mkdir -p /var/log/mysite
sudo chown -R tendenci: /var/log/mysite
sudo chown -R tendenci: /var/www/mysite/media/

# ✅ Update DB config inside existing settings.py (if needed)
SETTINGS_FILE="/var/www/mysite/conf/settings.py"
if [ -f "$SETTINGS_FILE" ]; then
  echo "Updating database config in settings.py..."

  # Replace or insert DATABASES config block using sed
  sed -i '/^DATABASES = {/,/^}/d' "$SETTINGS_FILE"

  cat >> "$SETTINGS_FILE" << EOF

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'tendenci'),
        'USER': os.environ.get('DB_USER', 'tendenci'),
        'PASSWORD': os.environ.get('DB_PASS', 'tendenci'),
        'HOST': os.environ.get('DB_HOST', 'db'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}
EOF
else
  echo "ERROR: settings.py not found at $SETTINGS_FILE"
  echo "This indicates that the Tendenci project was not created properly."
  echo "Please check the setup container logs for any errors during project creation."
  exit 1
fi

# Copy Juniper theme if not already present
THEME_DIR="/var/www/mysite/themes/juniper"
if [ ! -d "$THEME_DIR" ]; then
  echo "Copying Juniper theme..."
  mkdir -p "$THEME_DIR"
  TENDENCI_PATH=$(python -c "import tendenci, os; print(os.path.dirname(tendenci.__file__))")
  cp -r "$TENDENCI_PATH/themes/juniper/"* "$THEME_DIR/" || echo "Juniper theme not found."
fi

# Set safe permissions
chmod -R 755 media/ themes/

# Run Django management commands
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
  echo "ERROR: manage.py not found. Cannot continue."
  exit 1
fi

echo "Setup process finished."
