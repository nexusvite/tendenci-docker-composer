# Tendenci AMS Docker Setup

This Docker Compose setup allows you to quickly deploy Tendenci Association Management System with all required dependencies using a multi-container architecture.

## Prerequisites

- Docker Desktop installed and running on Windows 11
- At least 4GB of RAM allocated to Docker

## Components

This setup includes:

1. **PostgreSQL 17 with PostGIS 3.4**: Database service with spatial extensions required by Tendenci
2. **Setup Container**: Runs once to initialize the Tendenci application (Python 3.12)
3. **Tendenci Application Container**: Runs the Tendenci application server (Python 3.12)
4. **Nginx Container**: Reverse proxy for the application (Latest version)

## Architecture

```
┌─────────────┐    ┌──────────────┐    ┌──────────────┐
│   Nginx     │    │  Tendenci    │    │  PostgreSQL  │
│  Container  │◄──►│   App        │◄──►│   Database   │
│ (Port 8080) │    │ (Port 9900)  │    │ (Port 5432)  │
└─────────────┘    └──────────────┘    └──────────────┘
                         │
                         ▼
                   ┌──────────────┐
                   │  Setup       │
                   │ Container    │
                   └──────────────┘
```

## Quick Start

1. Clone or download this repository to your local machine
2. Open a terminal in the directory containing the docker-compose.yml file
3. Run the following command to start the services:

```bash
docker-compose up -d
```

4. Wait for the services to start (this may take a few minutes on the first run as the application initializes)
5. Access Tendenci through Nginx at http://localhost:8080

## First-time Setup

The setup container will automatically run when you start the services for the first time. It will:

1. Initialize the PostgreSQL database with required extensions
2. Create the Tendenci project
3. Set up the database schema
4. Load default data
5. Create a superuser account

After the initial setup is complete, you can create a superuser account by running:

```bash
docker-compose exec app python manage.py createsuperuser
```

## Configuration

### Environment Variables

You can customize the setup by modifying the environment variables in the `docker-compose.yml` file:

- `DB_NAME`: Database name (default: tendenci)
- `DB_USER`: Database user (default: tendenci)
- `DB_PASS`: Database password (default: tendenci)
- `SECRET_KEY`: Django secret key (change for production)
- `SITE_SETTINGS_KEY`: Tendenci site settings key (change for production)
- `DEBUG`: Debug mode (default: True)

### Data Persistence

The setup uses Docker volumes to persist data:

- `postgres_data`: PostgreSQL data
- `tendenci_media`: Media files
- `tendenci_themes`: Theme files
- `tendenci_logs`: Log files
- `tendenci_whoosh`: Search index files
- `tendenci_static`: Static files

## Managing the Application

### Starting the services

```bash
docker-compose up -d
```

### Stopping the services

```bash
docker-compose down
```

### Viewing logs

```bash
docker-compose logs -f
```

### Accessing the application container

```bash
docker-compose exec app bash
```

### Running management commands

```bash
docker-compose exec app python manage.py [command]
```

### Running the setup container manually

If you need to re-run the setup (e.g., after updating the application):

```bash
docker-compose up setup
```

## Development vs Production

This setup is configured for development purposes. For production deployment, consider:

1. Changing the `SECRET_KEY` and `SITE_SETTINGS_KEY` to secure values
2. Setting `DEBUG=False`
3. Using HTTPS with proper SSL certificates
4. Setting up proper backup procedures for the data volumes
5. Allocating more resources (CPU, RAM) to the containers
6. Using a production-ready database solution
7. Implementing proper security measures

## Troubleshooting

### Database Connection Issues

If you encounter database connection issues, ensure that:
1. The database container is running (`docker-compose ps`)
2. The database initialization completed successfully (`docker-compose logs db`)

### Permission Issues

If you encounter permission issues, you may need to adjust the file permissions on the host system for the mounted volumes.

### First Run Takes Too Long

The first run may take several minutes as the application initializes the database and loads default data. This is normal.

## Customization

You can customize this setup by:

1. Modifying the Dockerfiles to include additional dependencies
2. Changing the PostgreSQL version in docker-compose.yml
3. Modifying the nginx.conf for custom proxy settings
4. Adding additional services as needed
5. Modifying the setup.sh script to include additional setup steps

## License

This Docker setup is provided as-is without any warranty. Please refer to the Tendenci project for licensing information.