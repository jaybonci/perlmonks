# PerlMonks Development Environment

This document covers the Docker-based development environment for PerlMonks.

## Prerequisites

- Docker and Docker Compose
- ~3GB disk space for the SQLite database import
- Ports 9180, 9543, and 9406 available

## Quick Start

```bash
# Build and start everything
./docker/devbuild.sh

# Access the site
open http://localhost:9180
```

First-time build takes 10-15 minutes due to the SQLite database import (~1.5GB).

## Architecture

### Containers

| Container | Purpose | Ports |
|-----------|---------|-------|
| pmdevdb | MySQL 8.0 database | 9406:3306 |
| pmdevapp | Apache + mod_perl | 9180:80, 9543:443 |

### Network

Both containers run on the `pm-dev-net` Docker network. The app container connects to the database using the hostname `pmdevdb`.

### Port Selection

Ports are intentionally different from Everything2 development:

| Service | PerlMonks | Everything2 |
|---------|-----------|-------------|
| HTTP | 9180 | 9080 |
| HTTPS | 9543 | 9443 |
| MySQL | 9406 | 3306 |

This allows running both development environments simultaneously.

## Build Scripts

### devbuild.sh

```bash
./docker/devbuild.sh          # Build everything
./docker/devbuild.sh --db     # Build database only
./docker/devbuild.sh --app    # Rebuild app only (faster)
./docker/devbuild.sh --clean  # Clean and rebuild
```

### devclean.sh

```bash
./docker/devclean.sh          # Stop containers
./docker/devclean.sh --full   # Remove containers and images
```

## Database

### Connection Details

- **Host**: localhost (or `pmdevdb` from within containers)
- **Port**: 9406
- **Database**: perlmonks
- **User**: pmuser
- **Password**: pmpass

### Connecting

```bash
# From host
mysql -h localhost -P 9406 -u pmuser -ppmpass perlmonks

# From within app container
mysql -h pmdevdb -u pmuser -ppmpass perlmonks
```

### Schema Overview

The database contains ~88 tables with node-based architecture:

- **node**: Core table (~1.3M records) - base for all content
- **user**: User accounts (~97K records)
- **nodetype**: Defines node types (~112 types)
- **typeversion**: Extended nodetype data
- **setting**: Site configuration
- **links**: Node relationships

Key node types: document, user, usergroup, e2node, writeup

### Data Import

The database is populated from `db/perlmonks.sqlite` during first startup. The import process:

1. Starts MySQL in non-networked mode
2. Runs `tools/sqlite_to_mysql.pl` to convert and import data
3. Runs `tools/seeds.pl` to set development passwords
4. Restarts MySQL with networking enabled

### seeds.pl

Sets known passwords for development login:

| User ID | Username | Password |
|---------|----------|----------|
| 113 | root | blah |
| 112 | qauser | blah |
| 979 | vroom | blah |

## Application Container

### Directory Structure

```
/var/everything/
├── ecore/           # Everything Engine libraries
├── etc/             # Configuration files
└── www/             # Web root

/var/libraries/
└── lib/perl5/       # CPAN dependencies

/var/log/everything/ # Application logs
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| PM_ENVIRONMENT | development | Environment name |
| PM_DBHOST | pmdevdb | Database hostname |
| PM_DBPORT | 3306 | Database port |

### Configuration

Configuration is in `/var/everything/etc/development.json`:

```json
{
  "environment": "development",
  "database": {
    "host": "pmdevdb",
    "port": 3306,
    "name": "perlmonks",
    "user": "pmuser",
    "password": "pmpass"
  }
}
```

### Request Handling

Apache is configured for mod_perl with ModPerl::Registry:

- All `.pl` files in `/var/everything/www/` are handled by mod_perl
- Entry point is `index.pl`
- Uses `Everything::HTML::mod_perlInit()` for request handling

## Troubleshooting

### Database initialization timeout

If the build times out waiting for database initialization:

1. Check the timeout in `docker/devbuild.sh` (currently 900 seconds)
2. View database logs: `docker logs pmdevdb`
3. Check if import is still running: `docker exec pmdevdb ps aux`

### Connection refused

1. Ensure database container is running: `docker ps`
2. Check database is listening: `docker exec pmdevdb mysqladmin ping`
3. Verify network: `docker network inspect pm-dev-net`

### Apache not responding

1. Check Apache is running: `docker exec pmdevapp ps aux | grep apache`
2. View Apache logs: `docker exec pmdevapp cat /var/log/apache2/error.log`
3. Check mod_perl initialization: `docker logs pmdevapp`

### View container logs

```bash
docker logs pmdevdb      # Database logs
docker logs pmdevapp     # Application logs
docker logs -f pmdevapp  # Follow logs in real-time
```

### Shell access

```bash
docker exec -it pmdevdb bash   # Database container
docker exec -it pmdevapp bash  # Application container
```

## VS Code Integration

The `.vscode/tasks.json` provides build tasks:

- **Ctrl+Shift+B**: Build PerlMonks dev environment
- Task palette includes: Rebuild app only, Stop containers, Clean everything

## Differences from Everything2

| Aspect | PerlMonks | Everything2 |
|--------|-----------|-------------|
| Templates | No Mason | Mason-based |
| Dependencies | cpanfile | Carton |
| AWS | None | S3, etc. |
| Image processing | Not used | ImageMagick |

## Adding Dependencies

Edit `cpanfile` and rebuild the app container:

```bash
./docker/devbuild.sh --app
```

## Known Issues

1. **Hardcoded paths**: Some ecore libraries have hardcoded `perlmonks.org` URLs
2. **Database name**: `NodeBase.pm` maps 'perlmonks' to 'perlmonk_ebase' internally
3. **Error log path**: Hardcoded to `/usr/tmp/everything.errlog`

These will be addressed as part of the unification effort.
