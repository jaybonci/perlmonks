#!/bin/bash
#
# PerlMonks Development Environment Cleanup Script
#
# Usage:
#   ./docker/devclean.sh          # Stop containers
#   ./docker/devclean.sh --full   # Stop containers and remove images
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

FULL_CLEAN=false

if [ "$1" = "--full" ]; then
    FULL_CLEAN=true
fi

echo "========================================="
echo "PerlMonks Development Environment Cleanup"
echo "========================================="

# Stop and remove containers
echo "Stopping containers..."
docker stop $APP_CONTAINER 2>/dev/null && echo "  Stopped $APP_CONTAINER" || true
docker stop $DB_CONTAINER 2>/dev/null && echo "  Stopped $DB_CONTAINER" || true

echo "Removing containers..."
docker rm $APP_CONTAINER 2>/dev/null && echo "  Removed $APP_CONTAINER" || true
docker rm $DB_CONTAINER 2>/dev/null && echo "  Removed $DB_CONTAINER" || true

if [ "$FULL_CLEAN" = true ]; then
    echo "Removing images..."
    docker rmi $APP_IMAGE 2>/dev/null && echo "  Removed $APP_IMAGE" || true
    docker rmi $DB_IMAGE 2>/dev/null && echo "  Removed $DB_IMAGE" || true

    echo "Removing network..."
    docker network rm $NETWORK_NAME 2>/dev/null && echo "  Removed $NETWORK_NAME" || true
fi

echo ""
echo "Cleanup complete!"

if [ "$FULL_CLEAN" = true ]; then
    echo "Run './docker/devbuild.sh' to rebuild everything."
else
    echo "Run './docker/devbuild.sh' to restart containers."
    echo "Run './docker/devclean.sh --full' to also remove images."
fi
