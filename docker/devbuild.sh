#!/bin/bash
#
# PerlMonks Development Environment Build Script
#
# Usage:
#   ./docker/devbuild.sh            # Build everything
#   ./docker/devbuild.sh --db       # Build database only
#   ./docker/devbuild.sh --app      # Build app only (requires db running)
#   ./docker/devbuild.sh --clean    # Clean and rebuild
#   ./docker/devbuild.sh --forever  # Wait forever for startup (no timeout)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Container/image names
NETWORK_NAME="pm-dev-net"
APP_IMAGE="perlmonks/pmapp"
APP_CONTAINER="pmdevapp"
DB_IMAGE="perlmonks/pmdb"
DB_CONTAINER="pmdevdb"

# Ports (different from E2 to allow parallel development)
HTTP_PORT=9180
HTTPS_PORT=9543
MYSQL_PORT=9406

# Parse arguments
BUILD_DB=true
BUILD_APP=true
CLEAN=false
FOREVER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --db)
            BUILD_APP=false
            shift
            ;;
        --app)
            BUILD_DB=false
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --forever)
            FOREVER=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--db|--app|--clean|--forever]"
            exit 1
            ;;
    esac
done

cd "$PROJECT_DIR"

echo "========================================="
echo "PerlMonks Development Environment Build"
echo "========================================="
echo "Project: $PROJECT_DIR"
echo "Network: $NETWORK_NAME"
echo "Ports:   HTTP=$HTTP_PORT, HTTPS=$HTTPS_PORT, MySQL=$MYSQL_PORT"
echo ""

# Clean if requested
if [ "$CLEAN" = true ]; then
    echo "Cleaning existing containers..."
    docker stop $APP_CONTAINER 2>/dev/null || true
    docker rm $APP_CONTAINER 2>/dev/null || true
    docker stop $DB_CONTAINER 2>/dev/null || true
    docker rm $DB_CONTAINER 2>/dev/null || true
    echo "Removing images..."
    docker rmi $APP_IMAGE 2>/dev/null || true
    docker rmi $DB_IMAGE 2>/dev/null || true
    echo "Clean complete."
    echo ""
fi

# Create network if it doesn't exist
if ! docker network inspect $NETWORK_NAME >/dev/null 2>&1; then
    echo "Creating Docker network: $NETWORK_NAME"
    docker network create $NETWORK_NAME
fi

#
# Build and start database container
#
build_database() {
    echo ""
    echo "========================================="
    echo "Building Database Container"
    echo "========================================="

    # Check if container already running
    if docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
        echo "Database container already running."
        return 0
    fi

    # Remove stopped container if exists
    docker rm $DB_CONTAINER 2>/dev/null || true

    # Build image
    echo "Building database image..."
    docker build \
        -t $DB_IMAGE \
        -f docker/pmdb/Dockerfile \
        .

    # Start container
    echo "Starting database container..."
    docker run -d \
        --name $DB_CONTAINER \
        --network $NETWORK_NAME \
        --publish ${MYSQL_PORT}:3306 \
        $DB_IMAGE

    # Wait for database to be ready
    echo "Waiting for database initialization..."
    READY_FLAG="/etc/everything/dev_db_ready"
    MAX_WAIT=900  # 15 minutes for large SQLite import (~1.5GB)
    WAIT_COUNT=0

    while ! docker exec $DB_CONTAINER test -f $READY_FLAG 2>/dev/null; do
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ "$FOREVER" = false ] && [ $WAIT_COUNT -ge $MAX_WAIT ]; then
            echo "ERROR: Database initialization timed out after ${MAX_WAIT}s"
            echo "Check logs: docker logs $DB_CONTAINER"
            exit 1
        fi
        if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
            echo "  Still waiting... (${WAIT_COUNT}s)"
        fi
        sleep 1
    done

    echo "Database is ready!"
}

#
# Build and start application container
#
build_application() {
    echo ""
    echo "========================================="
    echo "Building Application Container"
    echo "========================================="

    # Check if database is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
        echo "ERROR: Database container is required but not running."
        echo "Run './docker/devbuild.sh' or './docker/devbuild.sh --db' first."
        exit 1
    fi

    # Remove existing container
    docker stop $APP_CONTAINER 2>/dev/null || true
    docker rm $APP_CONTAINER 2>/dev/null || true

    # Build image
    echo "Building application image..."
    docker build \
        -t $APP_IMAGE \
        -f docker/pmapp/Dockerfile \
        .

    # Start container
    echo "Starting application container..."
    docker run -d \
        --name $APP_CONTAINER \
        --network $NETWORK_NAME \
        --publish ${HTTP_PORT}:80 \
        --publish ${HTTPS_PORT}:443 \
        --env PM_ENVIRONMENT=development \
        --env PM_DBHOST=$DB_CONTAINER \
        --env PM_DBPORT=3306 \
        $APP_IMAGE

    # Wait for Apache to start
    echo "Waiting for Apache to start..."
    MAX_WAIT=60
    WAIT_COUNT=0

    while ! curl -s http://localhost:${HTTP_PORT}/ >/dev/null 2>&1; do
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ "$FOREVER" = false ] && [ $WAIT_COUNT -ge $MAX_WAIT ]; then
            echo "WARNING: Apache may not be responding yet."
            echo "Check logs: docker logs $APP_CONTAINER"
            break
        fi
        if [ "$FOREVER" = true ] && [ $((WAIT_COUNT % 30)) -eq 0 ]; then
            echo "  Still waiting for Apache... (${WAIT_COUNT}s)"
        fi
        sleep 1
    done

    echo "Application container started!"
}

#
# Main build flow
#
if [ "$BUILD_DB" = true ]; then
    build_database
fi

if [ "$BUILD_APP" = true ]; then
    build_application
fi

echo ""
echo "========================================="
echo "Build Complete!"
echo "========================================="

if [ "$BUILD_DB" = true ]; then
    echo "Database:    mysql -h localhost -P $MYSQL_PORT -u pmuser -ppmpass perlmonks"
fi

if [ "$BUILD_APP" = true ]; then
    echo "Application: http://localhost:$HTTP_PORT"
fi

echo ""
echo "Useful commands:"
echo "  docker logs $DB_CONTAINER      # Database logs"
echo "  docker logs $APP_CONTAINER     # Application logs"
echo "  docker exec -it $DB_CONTAINER bash    # Shell into database"
echo "  docker exec -it $APP_CONTAINER bash   # Shell into app"
echo "  ./docker/devclean.sh           # Stop and remove containers"
echo "========================================="
