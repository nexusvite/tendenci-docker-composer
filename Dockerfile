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
    git \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install dependencies
RUN pip install --upgrade pip setuptools wheel

# Install Tendenci (requires git for dependencies)
RUN pip install tendenci --upgrade

# Create app directories
RUN mkdir -p /srv/venv_tendenci /var/www/ /var/log/ && \
    chmod -R 755 /var/www /var/log

# Create a non-root user
RUN useradd -m -u 1000 tendenci && \
    usermod -aG sudo tendenci && \
    echo "tendenci ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set ownership
RUN chown -R tendenci: /var/www /var/log /srv/venv_tendenci

# Set working directory
WORKDIR /var/www

# Switch to tendenci user before project creation
USER tendenci

# Create Tendenci project
RUN tendenci startproject mysite

# Set working directory to the newly created site
WORKDIR /var/www/mysite

# Expose Django port
EXPOSE 9900

# Run server
CMD ["python", "manage.py", "runserver", "0.0.0.0:9900"]
