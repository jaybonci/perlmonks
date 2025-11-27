# PerlMonks Development Environment

This is a development snapshot of PerlMonks, the Perl programming community website that has been running since 1999. PerlMonks and Everything2 share a common heritage - both were built on the "Everything Engine."

## Prerequisites

- **Docker Desktop** (or Docker Engine on Linux)
- **SQLite database snapshot** of PerlMonks (not included in this repository)

## Getting Started

### 1. Install Docker

Install Docker Desktop from https://www.docker.com/products/docker-desktop/ or use your system's package manager.

### 2. Place the Database Snapshot

Copy your PerlMonks SQLite database snapshot to:

```
db/perlmonks.sqlite
```

The database file is approximately 1.5GB and is not included in this repository.

### 3. Build and Start the Environment

```bash
./docker/devbuild.sh --forever
```

**Note:** The `--forever` flag disables timeouts. The first build converts the SQLite database to MySQL, which can take 10-15 minutes or longer on older machines. The conversion only happens once - subsequent builds will reuse the existing MySQL data.

### 4. Access the Site

Once the build completes:

- **Website:** http://localhost:9180
- **MySQL:** `mysql -h localhost -P 9406 -u pmuser -ppmpass perlmonks`

### 5. Development Shell

To get a shell inside the application container:

```bash
./tools/shell.sh
```

This drops you into `/var/everything` where the application code lives. You can also access the database container:

```bash
./tools/shell.sh db
```

## Development Users

The build process seeds development passwords for testing:

| Username | Password |
|----------|----------|
| root     | blah     |
| qauser   | blah     |
| vroom    | blah     |

## Common Commands

```bash
# Build everything (first time takes 10-15 mins for DB import)
./docker/devbuild.sh --forever

# Rebuild just the app container (fast - use for code changes)
./docker/devbuild.sh --app

# Stop containers
./docker/devclean.sh

# Clean everything including images (full rebuild)
./docker/devclean.sh --full

# Shell into containers
./tools/shell.sh        # App container
./tools/shell.sh db     # Database container
```

## Architecture

- **Apache + CGI** (mod_perl has compatibility issues with Ubuntu 24.04's threaded Apache)
- **MySQL 8.0** database (converted from SQLite on first run)
- **Perl 5.38** on Ubuntu 24.04

### Directory Structure

```
/var/everything/          # Main application directory (inside container)
├── ecore/                # Everything Engine core libraries
├── etc/                  # Configuration files
├── www/                  # Web root (index.pl entry point)
└── db/                   # Database files (SQLite source)
```

## Changes Made for Docker Development

The following modifications were made to run PerlMonks in a Docker development environment:

### Library Updates

The `ecore/` libraries are the production libraries. Files removed (conflicted with system/CPAN modules):
- `Config.pm`, `CGI.pm`, `CGI/Util.pm`, `LWP/Simple.pm`, `Mail/Sender.pm`

### Code Patches

1. **Everything/Password.pm** - Replaced with a MySQL connection shim. Production connects to MySQL, but the sanitized database snapshot distributed to developers is SQLite. This Docker environment converts SQLite to MySQL on first run, and this shim reads database credentials from `/var/everything/etc/development.json` or environment variables.

2. **Everything/HTML.pm (line 1730)** - Removed `HTTP/1.1 200 OK` output from `printHeader()`. This NPH-style header works under mod_perl but breaks in CGI mode where Apache handles the status line.

### Configuration

- Database credentials are configured in `etc/development.json`
- Environment variables `PM_DBHOST`, `PM_DBPORT`, and `PM_ENVIRONMENT` control database connectivity
- Apache is configured for CGI mode (not mod_perl) due to DynaLoader conflicts

## Known Issues

1. **CGI Mode Only** - Running in CGI mode instead of mod_perl due to DynaLoader conflicts with Ubuntu 24.04's threaded Apache
2. **Some htmlcode errors** - Minor errors may appear in page output that need debugging

## Related Projects

This codebase shares heritage with Everything2: https://github.com/everything2/everything2

## License

PerlMonks is built on the Everything Engine. See individual source files for license information.
