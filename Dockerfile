FROM python:3.12-slim

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    postgresql-client \
    curl \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create directories with proper permissions
RUN mkdir -p /srv/venv_tendenci && \
    mkdir -p /var/www/ && \
    mkdir -p /var/log/mysite && \
    chmod -R 755 /var/www && \
    chmod -R 755 /var/log

# Upgrade pip and install dependencies
RUN pip install --upgrade pip setuptools wheel

# Install Tendenci
RUN pip install tendenci --upgrade

# Create a non-root user with sudo privileges
RUN useradd -m -u 1000 tendenci && \
    usermod -aG sudo tendenci && \
    echo "tendenci ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set ownership
RUN chown -R tendenci: /var/www/ /var/log/mysite /srv/venv_tendenci

# Set working directory
WORKDIR /var/www/

# Expose port
EXPOSE 9900

# Switch to tendenci user
USER tendenci

# Command to run the application
CMD ["python", "manage.py", "runserver", "0.0.0.0:9900"]