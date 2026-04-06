# Docker Dev Environment

Local PHP development stack with Nginx, MySQL, multiple PHP-FPM versions, Memcached, MinIO, and Adminer.

## What Is This?

This repo sets up a **shared local development environment** using Docker. Instead of installing PHP, MySQL, and Nginx directly on your machine, everything runs in containers — isolated, reproducible, and easy to reset.

**PHP-FPM** is the PHP process manager that handles PHP requests. This stack includes multiple PHP versions so different projects can each use the PHP version they require, all running at the same time.

## Docker vs Docker Compose

| | Docker | Docker Compose |
|---|---|---|
| Unit | Single container | Multiple containers |
| Config | CLI flags | `docker-compose.yml` |
| Use case | Run one thing | Run a full stack |
| Command | `docker run ...` | `docker compose up` |
| Networking | Manual | Auto creates a shared network |
| Volumes | Manual | Defined in compose file |

**Docker** is the engine that runs containers. **Docker Compose** orchestrates multiple containers together as a stack.

Running MySQL with plain Docker:
```bash
docker run -e MYSQL_ROOT_PASSWORD=root -p 3306:3306 mysql:8.0
```

With Docker Compose you define MySQL, PHP, Nginx together and start everything with one command:
```bash
dc up -d
```

This repo is entirely Docker Compose — Docker itself is just the engine running underneath.

**When to use Docker directly:**
- Running a quick one-off container to test something
- Building and tagging a single image
- Debugging a specific container in isolation

**When to use Docker Compose:**
- Running a full dev stack (PHP + MySQL + Nginx + etc.)
- Any time you have more than one container that need to talk to each other
- When you want one command to start and stop everything

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac/Windows) or [Docker Engine](https://docs.docker.com/engine/install/) (Linux)
- Git

## Services

| Service             | Description                          | URL / Port                        |
|---------------------|--------------------------------------|-----------------------------------|
| Nginx               | Web server / reverse proxy           | http://yourproject.local          |
| PHP 7.4             | PHP-FPM 7.4 ⚠️ EOL Nov 2022          | internal only                     |
| PHP 8.1             | PHP-FPM 8.1 ⚠️ EOL Dec 2025          | internal only                     |
| PHP 8.2             | PHP-FPM 8.2 ✅ Active (EOL Dec 2026) | internal only                     |
| PHP 8.3             | PHP-FPM 8.3 ✅ Active (EOL Dec 2027) | internal only *(optional)*        |
| MySQL 8.0           | Database                             | localhost:3306                    |
| Memcached           | Cache                                | localhost:11211                   |
| MinIO               | S3-compatible object storage         | localhost:9000                    |
| MinIO UI            | MinIO web console                    | http://localhost:9001             |
| Adminer             | Database management UI               | http://localhost:8081             |

> PHP 8.3 is marked **optional** — it is excluded from the default `dc up -d`. Start it manually only if a project needs it.
>
> Check current PHP EOL status: https://www.php.net/supported-versions.php

---

## Setup

### 1. Install Docker

- **Linux:** Follow the [official Docker Engine install guide](https://docs.docker.com/engine/install/) for your distro
- **Mac/Windows:** Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)

Verify Docker is installed:

```bash
docker --version
docker compose version
```

### 2. Clone the repo

```bash
git clone git@github.com:parasBisht/dev-stack.git
cd dev-stack
```

### 3. Set up the global alias

To run `dc` commands from any directory, add this to your `~/.bashrc` or `~/.zshrc`:

```bash
alias dc="docker compose -f $HOME/projects/dev-stack/docker-compose.yml"
export UID=$(id -u)
export GID=$(id -g)
```

Reload your shell:

```bash
source ~/.bashrc
```

> **Why `UID`/`GID`?** PHP runs as `www-data` inside containers. Exporting your user's UID/GID remaps `www-data` to match your host user — so files created inside containers are owned by you, not root.

### 4. Configure environment

```bash
cp .env.example .env
```

Edit `.env` — at minimum set these:

```env
PROJECTS_PATH=~/projects       # folder where all your projects live
MYSQL_ROOT_PASSWORD=secret     # choose a password
MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=minio123
```

See the [Environment Variables](#environment-variables) section for all options.

### 5. Build and start

Build only the PHP versions you need (avoid building all — EOL versions may have issues):

```bash
dc build php-fpm-82
dc up -d
```

### 6. Add local domains to /etc/hosts

`/etc/hosts` is a file on your machine that maps domain names to IP addresses — it's how `myproject.local` resolves to `127.0.0.1` (your own machine) without needing a real DNS record.

Add one line per project:

```bash
echo "127.0.0.1 myproject.local" | sudo tee -a /etc/hosts
```

---

## Adding a New Project

### 1. Create an Nginx site config

Sample configs are in `nginx/sites/examples/` — copy one as a starting point:

```bash
cp nginx/sites/examples/example.conf nginx/sites/myproject.conf
```

Edit `nginx/sites/myproject.conf`:

```nginx
server {
    listen 80;
    server_name myproject.local;
    root /var/www/myproject/public;   # path inside container
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ \.php$ {
        try_files $uri =404;
        set $upstream php-fpm-82:9000;   # change PHP version here
        fastcgi_pass $upstream;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_read_timeout 600;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

Available PHP upstream values:

| Upstream | PHP Version | Status |
|----------|-------------|--------|
| `php-fpm-74:9000` | PHP 7.4 | ⚠️ EOL |
| `php-fpm-81:9000` | PHP 8.1 | ⚠️ EOL |
| `php-fpm-82:9000` | PHP 8.2 | ✅ Active |
| `php-fpm-83:9000` | PHP 8.3 | ✅ Active, optional |

### 2. Reload Nginx

```bash
dc exec nginx nginx -s reload
```

### 3. Add the domain to /etc/hosts

```bash
echo "127.0.0.1 myproject.local" | sudo tee -a /etc/hosts
```

Your project is now accessible at `http://myproject.local`.

---

## Environment Variables

All configuration lives in `.env`. Copy `.env.example` to get started.

| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECTS_PATH` | `~/projects` | Path on your host where all projects live. Mounted into every PHP container as `/var/www`. Set this to wherever your code is. |
| `WORKDIR` | `/var/www` | Working directory inside containers. Matches the mount target of `PROJECTS_PATH`. |
| `MYSQL_ROOT_PASSWORD` | _(required)_ | MySQL root password. Used to connect from Adminer or any DB client. |
| `MYSQL_PORT` | `3306` | Host port MySQL is exposed on. Change to e.g. `3307` if 3306 is already in use. |
| `MEMCACHED_PORT` | `11211` | Host port for Memcached. |
| `MINIO_ROOT_USER` | _(required)_ | MinIO admin username — acts as the S3 access key in your app config. |
| `MINIO_ROOT_PASSWORD` | _(required)_ | MinIO admin password — acts as the S3 secret key. Minimum 8 characters. |
| `MINIO_PORT` | `9000` | MinIO S3 API port. Use this as the endpoint in your app. |
| `MINIO_CONSOLE_PORT` | `9001` | MinIO web console port. Open `http://localhost:9001` to manage buckets. |
| `NGINX_HTTP_PORT` | `80` | HTTP port. Keep as `80` so `.local` domains work in the browser without specifying a port. |
| `NGINX_HTTPS_PORT` | `443` | HTTPS port. |
| `ADMINER_PORT` | `8081` | Adminer web UI port. Open `http://localhost:8081`. |
| `ADMINER_DEFAULT_SERVER` | `mysql` | MySQL hostname Adminer connects to by default. Keep as `mysql` (Docker service name). |

> `UID` and `GID` are not set in `.env` — they are auto-detected from your shell. See [www-data & File Permissions](#www-data--file-permissions).

---

## Port Configuration

If a port is already in use on your machine, change it in `.env`:

```env
NGINX_HTTP_PORT=80        # change to e.g. 8080 if 80 is busy
NGINX_HTTPS_PORT=443      # change to e.g. 8443 if 443 is busy
MYSQL_PORT=3306           # change to e.g. 3307
MEMCACHED_PORT=11211
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
ADMINER_PORT=8081
```

To check what's using a port:

```bash
sudo lsof -i :80
sudo ss -tulnp | grep :3306
```

---

## www-data & File Permissions

PHP-FPM runs as `www-data` inside the container. The Dockerfiles remap `www-data` to match your host user's UID/GID automatically — so files created inside the container are owned by you on the host with no `permission denied` errors.

UID and GID are detected from your shell automatically. Add these exports to your `~/.bashrc` or `~/.zshrc`:

```bash
export UID=$(id -u)
export GID=$(id -g)
```

Then reload:

```bash
source ~/.bashrc
```

Docker Compose passes these to the build args — no need to set them manually in `.env`.

If you still see permission errors on project files:

```bash
sudo chown -R $USER:$USER ~/projects
```

---

## Commands Reference

### When to `build` vs `up` vs `restart`

> Replace `php-fpm-XX` with the PHP version your project needs e.g. `php-fpm-82`. Only build what you need — EOL versions may have build issues.

| Situation | Command |
|-----------|---------|
| First time setup | `dc build php-fpm-XX && dc up -d` |
| Changed a `Dockerfile` (added extension, package) | `dc up -d --build php-fpm-XX` |
| Changed `docker-compose.yml` (ports, volumes, env) | `dc up -d` |
| Changed an Nginx `.conf` site file | `dc exec nginx nginx -s reload` |
| Changed `nginx/nginx.conf` | `dc restart nginx` |
| Changed `.env` values | `dc up -d` |
| Service crashed or misbehaving | `dc restart php-fpm-XX` |
| Just starting your workday | `dc up -d` |
| Shutting down | `dc down` |
| Shutting down and wiping DB data | `dc down -v` ⚠️ deletes volumes |

> **Rule of thumb:** Use `--build` only when a `Dockerfile` changes. Everything else is `up -d` or `restart`.

---

### Stack

```bash
# Start all services in background
dc up -d

# Start only specific services
dc up -d nginx mysql php-fpm-XX

# Start the optional service
dc up -d php-fpm-83

# Stop all services (keeps data volumes intact)
dc down

# Stop and remove all volumes (wipes MySQL, MinIO data) ⚠️
dc down -v

# Check status of all containers
dc ps

# Show live CPU/memory usage per container
docker stats

# View all images built
docker images

# Remove unused images to free disk space
docker image prune -a
```

### Build

> **Important:** Do NOT run `dc build` without specifying a service — this builds ALL PHP versions including EOL ones. Only build the PHP version(s) your projects actually need.

```bash
# Build a specific PHP version only (recommended)
dc build php-fpm-XX

# Build and start a specific version
dc up -d --build php-fpm-XX

# Build multiple specific versions
dc build php-fpm-81 php-fpm-82

# Force rebuild from scratch ignoring cache (e.g. after base image update)
dc build --no-cache php-fpm-XX

# Build ALL images — only do this if you need every PHP version ⚠️
dc build
```

### Restart

```bash
# Restart a single service (keeps container, fast)
dc restart nginx

# Restart multiple services
dc restart nginx php-fpm-XX

# Full restart of everything
dc down && dc up -d

# Apply docker-compose.yml changes (ports, volumes, env vars)
dc up -d          # compose detects changes and recreates affected containers
```

### Logs

```bash
# Tail all service logs
dc logs -f

# Tail logs for a specific service
dc logs -f nginx
dc logs -f php-fpm-XX
dc logs -f mysql

# Show last 100 lines then follow
dc logs --tail=100 -f nginx

# Show logs without following (useful for quick checks)
dc logs nginx
```

### PHP

```bash
# Open an interactive shell inside a PHP container
dc exec php-fpm-XX bash

# Run Composer install
dc exec php-fpm-XX composer install -d /var/www/myproject

# Run Composer update
dc exec php-fpm-XX composer update -d /var/www/myproject

# Run Laravel Artisan commands
dc exec php-fpm-XX php /var/www/myproject/artisan migrate
dc exec php-fpm-XX php /var/www/myproject/artisan migrate:fresh --seed
dc exec php-fpm-XX php /var/www/myproject/artisan cache:clear
dc exec php-fpm-XX php /var/www/myproject/artisan queue:work

# Check PHP version
dc exec php-fpm-XX php -v

# List all loaded PHP extensions
dc exec php-fpm-XX php -m

# Show active php.ini files
dc exec php-fpm-XX php --ini

# Check a specific config value
dc exec php-fpm-XX php -r "echo ini_get('upload_max_filesize');"

# Run a PHP script directly
dc exec php-fpm-XX php /var/www/myproject/script.php
```

### Nginx

```bash
# Open a shell in Nginx container
dc exec nginx sh

# Test nginx config for syntax errors (always do this before reload)
dc exec nginx nginx -t

# Reload nginx after adding/editing a site config (zero downtime)
dc exec nginx nginx -s reload

# Hard restart nginx (use if reload doesn't pick up changes)
dc restart nginx

# View live access log
dc exec nginx tail -f /var/log/nginx/access.log

# View live error log (check here when a site returns 502/504)
dc exec nginx tail -f /var/log/nginx/error.log
```

### MySQL

```bash
# Open MySQL shell as root
dc exec mysql mysql -u root -p

# Create a new database
dc exec mysql mysql -u root -p -e "CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# List all databases
dc exec mysql mysql -u root -p -e "SHOW DATABASES;"

# Import a SQL dump into a database
dc exec -T mysql mysql -u root -p mydb < /path/to/dump.sql

# Export (dump) a database to a file
dc exec mysql mysqldump -u root -p mydb > /path/to/dump.sql

# Export all databases
dc exec mysql mysqldump -u root -p --all-databases > all-databases.sql

# Check MySQL status
dc exec mysql mysqladmin -u root -p status
```

### Memcached

```bash
# Check Memcached stats (hit rate, memory usage, connections)
dc exec memcached sh -c "echo stats | nc localhost 11211"

# Flush all cached data
dc exec memcached sh -c "echo flush_all | nc localhost 11211"
```

### MinIO

```bash
# Open a shell in MinIO
dc exec minio sh

# List buckets
dc exec minio mc ls local

# Create a bucket
dc exec minio mc mb local/mybucket
```

### Cleanup & Optimisation

Run these periodically to free up disk space and keep Docker lean.

```bash
# Show Docker disk usage breakdown (images, containers, volumes, cache)
docker system df

# Remove stopped containers, dangling images, unused networks, build cache
# Safe to run anytime — does NOT remove named volumes or running containers
docker system prune

# Same as above but also removes unused images (not just dangling ones)
# Use this when disk space is low
docker system prune -a

# Remove only dangling (untagged) images
docker image prune

# Remove all unused images including tagged ones not used by any container ⚠️
docker image prune -a

# Remove unused volumes (data not attached to any container) ⚠️
# Be careful — this deletes MySQL and MinIO data if containers are down
docker volume prune

# Nuclear option — removes everything: images, containers, volumes, networks ⚠️
docker system prune -a --volumes

# Remove build cache only (frees space without touching images/containers)
docker builder prune

# Remove build cache older than 24 hours
docker builder prune --filter until=24h
```

> **Tip:** Run `docker system df` first to see what's taking space before deciding what to prune.

---

## MySQL

Connect from your host machine using any DB client (TablePlus, DBeaver, etc.):

- Host: `127.0.0.1`
- Port: `3306`
- User: `root`
- Password: value of `MYSQL_ROOT_PASSWORD` in `.env`

Or use the web UI:
- **Adminer** → `http://localhost:8081` — auto-connects to MySQL using the `ADMINER_DEFAULT_SERVER` env var (set to `mysql` by default). No server field to fill in on the login page.

## MinIO

- API endpoint: `http://localhost:9000`
- Web console: `http://localhost:9001`
- Credentials: `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `.env`

In your app config, set the S3 endpoint to:
- `http://minio:9000` — when connecting from inside a container
- `http://localhost:9000` — when connecting from your host machine

## Troubleshooting

**Site shows 502 Bad Gateway**
- The PHP container isn't running. Check: `dc ps`
- Check PHP logs: `dc logs -f php-fpm-XX`
- Make sure the `set $upstream` in your nginx site config matches a running container name

**Permission denied on project files**
- Run: `sudo chown -R $USER:$USER ~/projects`
- Make sure `UID` and `GID` are exported in your shell before building

**Port already in use**
- Change the port in `.env` then run `dc up -d`
- Find what's using it: `sudo lsof -i :80`

**Container won't start**
- Check logs: `dc logs php-fpm-XX`
- Try a full restart: `dc down && dc up -d`

**php-fpm-83 not starting with `dc up -d`**
- This is an optional service excluded by default. Start it manually: `dc up -d php-fpm-83`

**Changes to `.env` not taking effect**
- Run `dc up -d` — Compose will recreate affected containers with the new values

---

## Common Customizations

### Adding a PHP Extension

PHP extensions are added in the `Dockerfile` of the PHP version that needs it. There are two ways depending on the extension.

**Built-in extension (via `docker-php-ext-install`)**

These are extensions bundled with PHP but not enabled by default — `bcmath`, `exif`, `soap`, `sockets`, `pcntl`, etc.

Open the Dockerfile for the PHP version you want, e.g. `php-fpm-82/Dockerfile`, and add the extension name to the `docker-php-ext-install` call:

```dockerfile
&& docker-php-ext-install \
    pdo_mysql \
    mbstring \
    bcmath \      # add new extension here
    zip \
    gd \
```

Then rebuild:

```bash
dc build php-fpm-82
dc up -d --build php-fpm-82
```

Verify it loaded:

```bash
dc exec php-fpm-82 php -m | grep bcmath
```

---

**Extension with a system library dependency**

Some extensions require a system library installed via apt before they can be compiled. Add the library to the `apt-get install` block and the extension to `docker-php-ext-install`:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    libfreetype6-dev \    # add library
    libjpeg62-turbo-dev \ # add library
    ...
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        gd \              # then install extension
        ...
```

---

**PECL extension**

Extensions not bundled with PHP are installed via PECL. Add the install and enable steps alongside the existing `memcached` installation:

```dockerfile
&& pecl install redis \
&& docker-php-ext-enable redis \
```

Then rebuild and verify:

```bash
dc build php-fpm-82
dc exec php-fpm-82 php -m | grep redis
```

---

### Changing PHP ini Settings

PHP settings (`upload_max_filesize`, `memory_limit`, `max_execution_time`, etc.) are configured by dropping a `.ini` file into `/usr/local/etc/php/conf.d/` inside the container. The easiest way is to add a `RUN` line in the Dockerfile:

```dockerfile
RUN echo "upload_max_filesize = 256M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "post_max_size = 256M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/custom.ini
```

Add this block at the end of the `RUN` chain in the relevant Dockerfile, then rebuild:

```bash
dc build php-fpm-82
dc up -d --build php-fpm-82
```

Verify the new value took effect:

```bash
dc exec php-fpm-82 php -r "echo ini_get('upload_max_filesize');"
```

Or check all active ini files:

```bash
dc exec php-fpm-82 php --ini
```

Alternatively, you can create a local `php.ini` file and mount it as a read-only bind mount in `docker-compose.yml`:

```yaml
php-fpm-82:
  volumes:
    - ${PROJECTS_PATH}:${WORKDIR:-/var/www}
    - ./php-fpm-82/custom.ini:/usr/local/etc/php/conf.d/custom.ini:ro
```

With this approach you can edit `php-fpm-82/custom.ini` on your host and apply changes with just a container restart — no rebuild needed:

```bash
dc restart php-fpm-82
```

---

### Changing MySQL Settings (my.cnf)

MySQL configuration lives in `mysql/my.cnf`. It is mounted read-only into the MySQL container at `/etc/mysql/conf.d/dev.cnf`. To change a setting, edit `mysql/my.cnf` on your host directly — no rebuild is needed for MySQL since it uses a pre-built image.

Common settings to adjust:

```ini
[mysqld]
# Increase buffer pool if you have more RAM available
innodb_buffer_pool_size = 2G    # default is 4G — reduce on lower-RAM machines

# Raise max connections if you see "too many connections" errors
max_connections = 100           # default is 50

# Increase temp table sizes for complex queries
tmp_table_size = 512M
max_heap_table_size = 512M

# Strict mode — remove NO_ZERO_IN_DATE if old data has zero dates
sql_mode = "NO_ENGINE_SUBSTITUTION"
```

After editing, restart MySQL to apply:

```bash
dc restart mysql
```

Verify the setting took effect:

```bash
dc exec mysql mysql -u root -p -e "SHOW VARIABLES LIKE 'max_connections';"
```

> The current `my.cnf` is tuned for a machine with a spinning HDD and 8+ GB RAM. Adjust `innodb_buffer_pool_size` if your machine has less available RAM — a safe rule is to set it to ~50-70% of total RAM.

---

## Dockerfile Explained

A look at what each instruction in a PHP-FPM Dockerfile does and why it's there.

```dockerfile
FROM php:8.3-fpm-bullseye
```

**`FROM`** — sets the base image. `php:8.3-fpm-bullseye` is an official PHP image from Docker Hub with PHP 8.3 and PHP-FPM pre-installed, built on Debian Bullseye. Every instruction after this builds on top of this image.

Debian versions used in this stack:

| Debian version | Used for | Why |
|----------------|----------|-----|
| Bullseye (11) | PHP 7.4, 8.1, 8.2, 8.3 | Has both `wkhtmltopdf` and `libmemcached-dev` |
| Bookworm (12) | Not used | Dropped `wkhtmltopdf` and `libmemcached-dev` |

---

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    wkhtmltopdf \
    libmemcached-dev \
    libzip-dev \
    ...
```

**`RUN`** — executes a shell command during the image build. Everything chained with `&&` runs as a single layer, which keeps the image smaller. `--no-install-recommends` skips optional packages that aren't needed.

The install sequence:

1. Install system libraries needed to compile PHP extensions (`libzip-dev`, `libpng-dev`, `libxml2-dev`, etc.)
2. Install `wkhtmltopdf` — used by some projects for HTML-to-PDF conversion
3. Install PHP extensions via `docker-php-ext-install` — a helper script built into the official PHP images (`pdo_mysql`, `mbstring`, `gd`, `intl`, `opcache`, etc.)
4. Install `memcached` via PECL — a PHP extension not bundled with PHP itself
5. Enable the PECL extension with `docker-php-ext-enable`
6. Clean up build tools (`g++`, `make`, `autoconf`) and apt cache (`/var/lib/apt/lists/`) — these are only needed to compile extensions, not to run them, so removing them keeps the image lean

---

```dockerfile
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Node.js + bower
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm \
    && npm install -g bower \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*
```

**`COPY --from`** — copies a single file from another Docker image without running it as a container. Here it pulls the `composer` binary from the official `composer` Docker image. This is the cleanest way to add Composer — no download scripts, no version pinning issues, always the official binary.

**Node.js + bower** — installed from Debian Bullseye's apt repos. `bower` is then installed globally via npm. The apt cache is cleared afterward to keep the image lean. Node is needed for front-end asset management (`bower install`) inside the container.

---

```dockerfile
ARG UID=1000
ARG GID=1000
ARG WORKDIR=/var/www
```

**`ARG`** — declares a build-time variable with an optional default. These values are injected when `dc build` runs, from the `args:` block in `docker-compose.yml`. They are only available during the build — not at container runtime.

- `UID` — your host user's numeric user ID (typically `1000` on Linux)
- `GID` — your host user's numeric group ID (typically `1000` on Linux)
- `WORKDIR` — the path inside the container where your projects will live

---

```dockerfile
RUN FPM_USER=$(grep -E '^\s*user\s*=' /usr/local/etc/php-fpm.d/www.conf | sed 's/.*=\s*//;s/\s*//g') \
    && FPM_GROUP=$(grep -E '^\s*group\s*=' /usr/local/etc/php-fpm.d/www.conf | sed 's/.*=\s*//;s/\s*//g') \
    && usermod -u ${UID} ${FPM_USER} \
    && groupmod -g ${GID} ${FPM_GROUP}
```

**UID/GID remapping** — PHP-FPM runs as `www-data` by default. This block reads the actual username and group from the PHP-FPM config file (`www.conf`), then changes `www-data`'s numeric UID and GID to match your host user using `usermod` and `groupmod`. The result: files written inside the container are owned by your user on the host — no `permission denied` errors when editing project files.

Why read from `www.conf` instead of hardcoding `www-data`? Different PHP base images may name this user differently. Detecting it dynamically works reliably across all PHP versions.

---

```dockerfile
WORKDIR ${WORKDIR}
```

**`WORKDIR`** — sets the default working directory inside the container. Any shell opened with `dc exec php-fpm-XX bash` starts here. Also the directory where Composer and PHP commands run by default when no path is specified.

---

## docker-compose.yml Explained

### Top-level: networks

```yaml
networks:
  web:
    driver: bridge
```

Defines a Docker network named `web` using the `bridge` driver. All services that join this network can reach each other by service name (e.g., `php-fpm-82`, `mysql`, `minio`). Without a shared network, containers are isolated and cannot communicate.

`bridge` is the standard network mode for single-host Docker setups — it creates a virtual network interface on the Docker host and assigns each container an internal IP.

---

### Top-level: volumes

```yaml
volumes:
  mysql-data:
  minio-data:
  memcached-data:
```

Declares **named volumes** — Docker-managed storage that persists across container restarts and `dc down`. Unlike bind mounts (which point to a folder on your host), named volumes are managed by Docker and stored internally under `/var/lib/docker/volumes/`.

- `mysql-data` — stores MySQL database files; survives restarts
- `minio-data` — stores MinIO object data (buckets and uploaded files); survives restarts
- `memcached-data` — declared at the top level but not mounted to the memcached service; effectively unused. Memcached is inherently ephemeral — cache is always lost on restart.

> **Warning:** `dc down -v` deletes all named volumes — including your MySQL data. Do not use `-v` unless you intend to wipe the database.

---

### Per-service: build

```yaml
build:
  context: ./php-fpm-83
  args:
    UID: ${UID:-1000}
    GID: ${GID:-1000}
    WORKDIR: ${WORKDIR:-/var/www}
```

- `context` — the directory Docker sends to the build engine. Must contain a `Dockerfile`.
- `args` — build-time variables passed into the Dockerfile as `ARG` values. `${UID:-1000}` means: use the value of `$UID` from the shell environment, falling back to `1000` if not set. This is how your host UID/GID flows into the container at build time.

Services with `build:` are custom images built from local Dockerfiles. Services with `image:` (Nginx, MySQL, MinIO, etc.) use pre-built images from Docker Hub and are never rebuilt locally.

---

### Per-service: profiles

```yaml
profiles: [optional]
```

Profiles mark services as opt-in. Services with a profile are **excluded from `dc up -d`** by default — they only start when explicitly named or when the profile is activated. PHP 8.3 uses the `optional` profile.

```bash
dc up -d php-fpm-83    # start a specific optional service
```

Services without `profiles:` always start with `dc up -d`.

---

### Per-service: restart

```yaml
restart: always
```

Tells Docker to restart the container automatically if it exits — whether due to a crash, an error, or the Docker daemon restarting (e.g., after a machine reboot). Most services use `always` so the dev stack comes back without manual intervention.

MinIO uses `restart: no` — it does not start automatically with `dc up -d` and will not restart on crash. Start it manually when needed:

```bash
dc up -d minio
```

---

### Per-service: volumes

```yaml
# Bind mount — maps a host path directly into the container
- ${PROJECTS_PATH}:${WORKDIR:-/var/www}

# Named volume — Docker-managed persistent storage
- mysql-data:/var/lib/mysql

# Read-only bind mount — container can read but not write
- ./mysql/my.cnf:/etc/mysql/conf.d/dev.cnf:ro
```

| Type | Format | What it does |
|------|--------|--------------|
| Bind mount | `host/path:/container/path` | Maps a directory from your machine into the container. Changes on either side are instantly visible on the other. |
| Named volume | `volume-name:/container/path` | Docker manages the storage. Persists across `dc down`, deleted by `dc down -v`. |
| Read-only mount | `host/path:/container/path:ro` | Container can read the file but cannot write to it. Used for config files. |

The `${PROJECTS_PATH}:${WORKDIR}` bind mount is how all PHP containers and Nginx share access to the same project code — they all mount the same host directory.

---

### Per-service: networks

```yaml
networks:
  - web
```

Attaches this service to the `web` network. All containers on the same network can reach each other using the service name as a hostname. This is why Nginx can reference `php-fpm-82:9000` and MySQL is reachable at hostname `mysql`.

---

### Per-service: depends_on

```yaml
depends_on:
  - php-fpm-74
  - php-fpm-71
```

Tells Compose to start the listed services before this one. Used on Nginx so the listed PHP-FPM containers are up before Nginx starts. Only the always-on services (`php-fpm-74`, `php-fpm-71`) are listed — optional services like `php-fpm-83` are omitted intentionally so Nginx can start without them.

Note: `depends_on` only waits for the container to *start*, not for the service inside it to be *ready*. For PHP-FPM this is fine — startup is fast.

---

### Per-service: ports

```yaml
ports:
  - "${NGINX_HTTP_PORT}:80"
  - "${NGINX_HTTPS_PORT}:443"
```

Maps a **host port** to a **container port** in `host:container` format. This is how services become accessible from your browser or other tools on your machine. Without `ports:`, a service is only reachable from other containers on the same Docker network.

PHP-FPM containers have no `ports:` entry — they are only accessed by Nginx internally over the Docker network, never directly from the host.

---

### Per-service: environment

```yaml
environment:
  MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
```

Passes environment variables into the running container. Values using `${}` are read from your `.env` file or shell environment at runtime. These are available to the process running inside the container — not during the build (that's what `args:` is for).

---

### Per-service: command

```yaml
command: server /data --console-address ":9001"
```

Overrides the default startup command of the container. Used for MinIO to specify the data directory and the web console port. Without this, MinIO would not know where to store data or which port to expose the UI on.

---

### Per-service: image

```yaml
image: nginx:alpine
image: mysql:8.0
image: memcached:alpine
image: minio/minio
```

Pulls a pre-built image from Docker Hub instead of building one locally. Format is `name:tag`.

- `:alpine` variants are built on Alpine Linux — minimal, smaller image size
- `:8.0`, `:latest` etc. pin to a specific version
- Services with `image:` have no local `Dockerfile` — everything is pre-configured by the image maintainer
