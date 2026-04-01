# Docker Dev Environment

Local PHP development stack with Nginx, MySQL, multiple PHP-FPM versions, Memcached, MinIO, Adminer, and phpMyAdmin.

## What Is This?

This repo sets up a **shared local development environment** using Docker. Instead of installing PHP, MySQL, and Nginx directly on your machine, everything runs in containers — isolated, reproducible, and easy to reset.

**PHP-FPM** is the PHP process manager that handles PHP requests. This stack includes multiple PHP versions so different projects can each use the PHP version they require, all running at the same time.

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Mac/Windows) or [Docker Engine](https://docs.docker.com/engine/install/) (Linux)
- Git

## Services

| Service    | Description                          | URL / Port                     |
|------------|--------------------------------------|--------------------------------|
| Nginx      | Web server / reverse proxy           | http://yourproject.local       |
| PHP 7.1    | PHP-FPM 7.1 ⚠️ EOL Dec 2019          | internal only                  |
| PHP 7.4    | PHP-FPM 7.4 ⚠️ EOL Nov 2022          | internal only                  |
| PHP 8.0    | PHP-FPM 8.0 ⚠️ EOL Nov 2023          | internal only *(optional)*     |
| PHP 8.1    | PHP-FPM 8.1 ✅ Active (EOL Dec 2025) | internal only                  |
| PHP 8.2    | PHP-FPM 8.2 ✅ Active (EOL Dec 2026) | internal only                  |
| PHP 8.3    | PHP-FPM 8.3 ✅ Active (EOL Dec 2027) | internal only *(optional)*     |
| MySQL 8.0  | Database                             | localhost:3306                 |
| Memcached  | Cache                                | localhost:11211                |
| MinIO      | S3-compatible object storage         | localhost:9000                 |
| MinIO UI   | MinIO web console                    | http://localhost:9001          |
| Adminer    | Database management UI               | http://localhost:8081          |
| phpMyAdmin | Database management UI               | http://localhost:8082          |

> PHP 8.0 and 8.3 are marked **optional** — they are excluded from the default `dc up -d`. Start them manually only if a project needs them.
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
dc build php-fpm-81 php-fpm-82
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
| `php-fpm-71:9000` | PHP 7.1 | ⚠️ EOL |
| `php-fpm-74:9000` | PHP 7.4 | ⚠️ EOL |
| `php-fpm-80:9000` | PHP 8.0 | ⚠️ EOL, optional |
| `php-fpm-81:9000` | PHP 8.1 | ✅ Active |
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
| `MYSQL_ROOT_PASSWORD` | _(required)_ | MySQL root password. Used to connect from Adminer, phpMyAdmin, or any DB client. |
| `MYSQL_PORT` | `3306` | Host port MySQL is exposed on. Change to e.g. `3307` if 3306 is already in use. |
| `MEMCACHED_PORT` | `11211` | Host port for Memcached. |
| `MINIO_ROOT_USER` | _(required)_ | MinIO admin username — acts as the S3 access key in your app config. |
| `MINIO_ROOT_PASSWORD` | _(required)_ | MinIO admin password — acts as the S3 secret key. Minimum 8 characters. |
| `MINIO_PORT` | `9000` | MinIO S3 API port. Use this as the endpoint in your app. |
| `MINIO_CONSOLE_PORT` | `9001` | MinIO web console port. Open `http://localhost:9001` to manage buckets. |
| `NGINX_HTTP_PORT` | `80` | HTTP port. Keep as `80` so `.local` domains work in the browser without specifying a port. |
| `NGINX_HTTPS_PORT` | `443` | HTTPS port. |
| `ADMINER_PORT` | `8081` | Adminer web UI port. Open `http://localhost:8081`. |
| `PMA_HOST` | `mysql` | MySQL hostname phpMyAdmin connects to. Keep as `mysql` (Docker service name). |
| `PMA_PORT` | `3306` | MySQL port phpMyAdmin connects to. Keep as `3306`. |
| `PMA_WEBPORT` | `8082` | Host port for phpMyAdmin web UI. Open `http://localhost:8082`. |

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
PMA_WEBPORT=8082
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

> Replace `php-fpm-XX` with the PHP version your project needs e.g. `php-fpm-82`, `php-fpm-81`. Only build what you need — EOL versions may have build issues.

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

# Start an optional service (php-fpm-80 or php-fpm-83)
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
- **Adminer** → `http://localhost:8081`
- **phpMyAdmin** → `http://localhost:8082`

## MinIO

- API endpoint: `http://localhost:9000`
- Web console: `http://localhost:9001`
- Credentials: `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `.env`

In your app config, set the S3 endpoint to:
- `http://minio:9000` — when connecting from inside a container
- `http://localhost:9000` — when connecting from your host machine

---

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

**php-fpm-80 or php-fpm-83 not starting with `dc up -d`**
- These are optional services excluded by default. Start them manually: `dc up -d php-fpm-80`

**Changes to `.env` not taking effect**
- Run `dc up -d` — Compose will recreate affected containers with the new values
