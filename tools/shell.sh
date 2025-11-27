#!/bin/bash
#
# Interactive Shell for PerlMonks Development Container
# Provides a bash shell inside the pmdevapp Docker container
#
# Usage:
#   ./tools/shell.sh              # Get a shell in /var/everything
#   ./tools/shell.sh /path        # Get a shell in a specific directory
#   ./tools/shell.sh db           # Get a shell in the database container
#

set -e

CONTAINER_NAME="pmdevapp"
WORKING_DIR="${1:-/var/everything}"

# Special case: if first arg is "db", shell into the database container
if [ "$1" = "db" ]; then
    CONTAINER_NAME="pmdevdb"
    WORKING_DIR="/var/everything"
fi

# Check if container is running
if ! docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
    echo "Error: Container '$CONTAINER_NAME' is not running."
    echo "Start it with: ./docker/devbuild.sh"
    exit 1
fi

echo "Entering shell in container '$CONTAINER_NAME' (working directory: $WORKING_DIR)"
echo "Type 'exit' or press Ctrl+D to leave the shell"
echo ""

# Execute interactive bash shell in the container
docker exec -it -w "$WORKING_DIR" $CONTAINER_NAME /bin/bash
