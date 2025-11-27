#!/bin/bash
#
# Apache2 wrapper for PerlMonks development container
# Waits for database, configures Apache, starts service
#

set -e

echo "========================================="
echo "PerlMonks Application Container Starting"
echo "========================================="

# Wait for database to be ready
DB_HOST="${PM_DBHOST:-pmdevdb}"
DB_PORT="${PM_DBPORT:-3306}"
MAX_WAIT=120
WAIT_COUNT=0

echo "Waiting for database at $DB_HOST:$DB_PORT..."
while ! mysqladmin ping -h "$DB_HOST" -P "$DB_PORT" --silent 2>/dev/null; do
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
        echo "ERROR: Database not available after ${MAX_WAIT}s"
        exit 1
    fi
    sleep 1
done
echo "Database is ready!"

# Generate Apache configuration if not exists
if [ ! -f /etc/apache2/sites-available/perlmonks.conf ]; then
    echo "Generating Apache configuration..."
    cat > /etc/apache2/sites-available/perlmonks.conf << 'APACHECONF'
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/everything/www

    # Log settings
    ErrorLog /var/log/everything/apache_error.log
    CustomLog /var/log/everything/apache_access.log combined
    LogLevel warn

    # Default to index.pl
    DirectoryIndex index.pl

    <Directory /var/everything/www>
        Options Indexes FollowSymLinks ExecCGI
        AllowOverride All
        Require all granted

        # Handle .pl files as CGI for now (simpler, avoids mod_perl DynaLoader issues)
        <Files "*.pl">
            SetHandler cgi-script
            Options +ExecCGI
        </Files>
    </Directory>

    # Set environment for CGI scripts
    SetEnv PERL5LIB /var/libraries/lib/perl5:/var/everything/ecore
    SetEnv PM_ENVIRONMENT development
    SetEnv PM_DBHOST pmdevdb
    SetEnv PM_DBPORT 3306

    # Static files bypass
    <LocationMatch "^/(css|js|images|static)/.*">
        SetHandler default-handler
    </LocationMatch>
</VirtualHost>
APACHECONF
fi

# Enable site and disable default
a2dissite 000-default 2>/dev/null || true
a2ensite perlmonks 2>/dev/null || true

# Ensure log directory exists and is writable
mkdir -p /var/log/everything
chmod 755 /var/log/everything
touch /var/log/everything/apache_error.log
touch /var/log/everything/apache_access.log

# Create Everything error log with permissive permissions for CGI/www-data
touch /tmp/everything.errlog
chmod 777 /tmp/everything.errlog

echo "Starting Apache..."
echo "Application will be available at http://localhost:9180"

# Start Apache in foreground
exec apache2ctl -D FOREGROUND
