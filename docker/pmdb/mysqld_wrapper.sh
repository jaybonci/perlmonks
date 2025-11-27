#!/bin/bash
#
# MySQL wrapper for PerlMonks development database container
# Initializes MySQL, imports SQLite data, starts service
#

set -e

MYSQL_DATABASE="perlmonks"
MYSQL_USER="pmuser"
MYSQL_PASSWORD="pmpass"
SQLITE_FILE="/var/everything/db/perlmonks.sqlite"
READY_FLAG="/etc/everything/dev_db_ready"

# Timing helper function
format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))
    if [ $minutes -gt 0 ]; then
        echo "${minutes}m ${remaining_seconds}s"
    else
        echo "${seconds}s"
    fi
}

CONTAINER_START_TIME=$(date +%s)

echo "========================================="
echo "PerlMonks Database Container Starting"
echo "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="

# Initialize MySQL if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MySQL data directory..."
    mysqld --initialize-insecure --user=mysql
fi

# Start MySQL in background for setup
echo "Starting MySQL for initialization..."
mysqld --user=mysql --skip-networking &
MYSQL_PID=$!

# Wait for MySQL to be ready
echo "Waiting for MySQL to start..."
for i in {1..60}; do
    if mysqladmin ping --silent 2>/dev/null; then
        break
    fi
    sleep 1
done

if ! mysqladmin ping --silent 2>/dev/null; then
    echo "ERROR: MySQL failed to start"
    exit 1
fi

echo "MySQL is running."

# Create database and user if not exists
echo "Setting up database and user..."
mysql -u root << EOSQL
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE}
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- Use mysql_native_password for compatibility with older DBD::mysql versions
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED WITH mysql_native_password BY '${MYSQL_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'localhost';

FLUSH PRIVILEGES;
EOSQL

# Check if we need to import data
TABLE_COUNT=$(mysql -u root -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DATABASE}';" 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" -lt "10" ]; then
    echo "Database appears empty, importing from SQLite..."

    if [ -f "$SQLITE_FILE" ]; then
        IMPORT_START_TIME=$(date +%s)
        echo ""
        echo ">>> SQLite Import Started at: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ">>> SQLite file: $SQLITE_FILE ($(du -h "$SQLITE_FILE" | cut -f1))"
        echo ""

        # Note: root user has no password after initialize-insecure
        perl /var/everything/tools/sqlite_to_mysql.pl \
            --sqlite="$SQLITE_FILE" \
            --database="$MYSQL_DATABASE" \
            --user="root" \
            --host="localhost"

        IMPORT_END_TIME=$(date +%s)
        IMPORT_DURATION=$((IMPORT_END_TIME - IMPORT_START_TIME))
        echo ""
        echo ">>> SQLite Import Completed at: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ">>> Import duration: $(format_duration $IMPORT_DURATION)"
        echo ""

        # Run seeds to set dev passwords
        SEEDS_START_TIME=$(date +%s)
        echo "Running seeds.pl to set development passwords..."
        perl /var/everything/tools/seeds.pl \
            --database="$MYSQL_DATABASE" \
            --user="root" \
            --host="localhost"

        SEEDS_END_TIME=$(date +%s)
        SEEDS_DURATION=$((SEEDS_END_TIME - SEEDS_START_TIME))
        echo ">>> Seeds completed in: $(format_duration $SEEDS_DURATION)"
    else
        echo "WARNING: SQLite file not found at $SQLITE_FILE"
        echo "Database will be empty."
    fi
else
    echo "Database already has $TABLE_COUNT tables, skipping import."
fi

# Stop the setup MySQL instance
echo "Restarting MySQL with networking enabled..."
kill $MYSQL_PID 2>/dev/null || true
wait $MYSQL_PID 2>/dev/null || true

# Touch ready flag
touch "$READY_FLAG"
echo "Database ready flag set: $READY_FLAG"

CONTAINER_READY_TIME=$(date +%s)
TOTAL_STARTUP_DURATION=$((CONTAINER_READY_TIME - CONTAINER_START_TIME))

echo "========================================="
echo "PerlMonks Database Ready"
echo "  Database: $MYSQL_DATABASE"
echo "  User: $MYSQL_USER"
echo "  Port: 3306 (mapped to 9406)"
echo ""
echo "  Total startup time: $(format_duration $TOTAL_STARTUP_DURATION)"
echo "  Ready at: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="

# Start MySQL in foreground with networking
exec mysqld --user=mysql --bind-address=0.0.0.0
