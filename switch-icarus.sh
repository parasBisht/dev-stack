#!/usr/bin/env bash
set -e

DOCKER_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ICARUS_DIR="/home/ucodesoft/projects/icarus"
UPSTREAM_FILE="$DOCKER_DIR/nginx/sites/icarus-php-upstream.inc"

usage() {
    echo "Usage: switch-icarus <74|81>"
    exit 1
}

[[ "$1" == "74" || "$1" == "81" ]] || usage

VERSION="$1"

if [[ "$VERSION" == "74" ]]; then
    UPSTREAM="php-fpm-74:9000"
    BRANCH="testing"
else
    UPSTREAM="php-fpm-81:9000"
    BRANCH="pb-php8-upgrade"
fi

echo "[1/4] Setting nginx upstream → $UPSTREAM"
echo "fastcgi_pass $UPSTREAM;" > "$UPSTREAM_FILE"

echo "[2/4] Reloading nginx"
docker exec docker-nginx-1 nginx -t
docker exec docker-nginx-1 nginx -s reload

echo "[3/4] Switching icarus branch → $BRANCH"
git -C "$ICARUS_DIR" checkout "$BRANCH"

echo "[4/4] Flushing Memcached"
docker exec docker-memcached-1 sh -c "echo flush_all | nc localhost 11211"

echo ""
echo "Done. Icarus is now on PHP $VERSION ($BRANCH)."
