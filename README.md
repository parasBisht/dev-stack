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
docker compose up -d
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
| MySQL 8.0           | Database ⚠️ 8.0 is EOL (Apr 2026) — see [MySQL](#mysql) | localhost:3306 |
| Memcached           | Cache                                | localhost:11211                   |
| Mailpit             | Catches outgoing mail (SMTP :1025)   | http://localhost:8025             |
| MinIO *(optional)*  | S3-compatible object storage         | localhost:9000                    |
| MinIO UI *(optional)* | MinIO web console                  | http://localhost:9001             |
| Adminer             | Database management UI               | http://localhost:8081             |

> PHP 8.3 and MinIO are marked **optional** — they are excluded from the default `docker compose up -d`. Start them with `docker compose --profile optional up -d php-fpm-83 minio` only if a project needs them.
>
> Check current PHP EOL status: https://www.php.net/supported-versions.php

---

## Quick Start

Everything below is run from the `dev-stack` folder. For the full explanation of each step, see [Setup](#setup).

```bash
# 1. get the stack
git clone git@github.com:parasBisht/dev-stack.git
cd dev-stack

# 2. configure
cp .env.example .env
#    edit .env: set PROJECTS_PATH (absolute path to your projects folder) and the passwords.
#    macOS only: also uncomment  SSH_AUTH_SOCK_HOST=/run/host-services/ssh-auth.sock

# 3. build the PHP versions you need and start
docker compose build php-fpm-74 php-fpm-81 php-fpm-82
docker compose up -d
docker compose ps          # mysql and mailhog should show "healthy"
```

**Serve a project** (example: a project in `$PROJECTS_PATH/myapp` on PHP 8.2 — the full walkthrough, with database and app settings, is in [Adding a New Site](#adding-a-new-site)):

```bash
# 4. nginx site: copy the example, then edit server_name, root and the php-fpm-XX upstream
cp nginx/sites/examples/example.conf nginx/sites/myapp.conf
docker compose exec nginx nginx -s reload

# 5. hosts entry
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
```

Open `http://myapp.local`. In the app's config use `mysql` as the database host (not `localhost`), `memcached` for memcached, and `mailhog` port `1025` for SMTP.

**Run commands inside a container** (always from the `dev-stack` folder):

```bash
docker compose exec php-fpm-82 sh -c 'cd /var/www/myapp && composer install'
docker compose exec php-fpm-82 sh -c 'cd /var/www/myapp && php bin/cake.php migrations migrate'
docker compose exec mysql mysql -uroot -p        # MySQL shell
```

**Everyday commands:**

| Task | Command |
|---|---|
| Start / stop everything | `docker compose up -d` / `docker compose stop` |
| Status and health | `docker compose ps` |
| Logs of one service | `docker compose logs -f php-fpm-82` |
| Reload nginx after editing a site file | `docker compose exec nginx nginx -s reload` |
| Rebuild a PHP image after a Dockerfile change | `docker compose up -d --build php-fpm-82` |
| Start the optional services | `docker compose --profile optional up -d php-fpm-83 minio` |

**Web UIs:** Adminer `http://localhost:8081` (server `mysql`, user `root`) · Mailpit `http://localhost:8025` · MinIO console `http://localhost:9001` (optional).

> ⚠️ Databases live in the `mysql-data` Docker volume. `docker compose down -v` or a Docker Desktop reset deletes them — see [Backups](#backups).

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

### 3. Configure environment

```bash
cp .env.example .env
```

Edit `.env` — at minimum set these:

```env
PROJECTS_PATH=~/projects       # folder where all your projects live
MYSQL_ROOT_PASSWORD=secret     # choose a password
MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=minio123
# macOS only — Docker Desktop's built-in ssh-agent forwarding (see "macOS vs Linux")
# SSH_AUTH_SOCK_HOST=/run/host-services/ssh-auth.sock
```

See the [Environment Variables](#environment-variables) section for all options.

### 4. Build and start

Build only the PHP versions you need (avoid building all — EOL versions may have issues):

```bash
docker compose build php-fpm-82
docker compose up -d
```

### 5. Add local domains to /etc/hosts

`/etc/hosts` is a file on your machine that maps domain names to IP addresses — it's how `myproject.local` resolves to `127.0.0.1` (your own machine) without needing a real DNS record.

Add one line per project:

```bash
echo "127.0.0.1 myproject.local" | sudo tee -a /etc/hosts
```

---

## macOS vs Linux

The stack runs on both. Images are multi-arch (`amd64` + `arm64`), so Apple Silicon runs everything natively. The differences:

| | macOS (Docker Desktop) | Linux (Docker Engine) |
|---|---|---|
| `PROJECTS_PATH` | use an absolute path, e.g. `/Users/you/code` | e.g. `/home/you/code` |
| `SSH_AUTH_SOCK_HOST` | `/run/host-services/ssh-auth.sock` | leave unset (your shell's `SSH_AUTH_SOCK` is used) |
| Ports 80/443 | free on macOS | may need `sudo`/capabilities or other ports in `.env` |
| Memory | raise Docker Desktop → Settings → Resources (≥ 6 GB for a large MySQL database) | uses host memory |

**Private git repos / `composer install` over SSH.** The PHP containers get your ssh-agent and `~/.ssh/known_hosts`. Load your key into the agent on the host first (`ssh-add` on Linux, `ssh-add --apple-use-keychain` on macOS, and again after a reboot), then check with `docker compose exec -u root php-fpm-74 ssh-add -l`. On macOS the forwarded socket is owned by root, so run git-over-SSH commands as root: `docker compose exec -u root php-fpm-74 sh -c 'cd /var/www/<project> && composer install'`. Your `~/.ssh/config` is deliberately **not** mounted — options like `UseKeychain` are macOS-only and break ssh inside the Linux containers.

**Base images.** The PHP images are built on Debian Bullseye, which is end-of-life: the Dockerfiles point apt at `archive.debian.org`. The wkhtmltopdf download follows the build architecture, and `memcached`/`apcu` are compiled from source because the `pecl` client is broken in these images.

---

## Adding a New Site

Every site needs the same five things: **code** in your projects folder, an **nginx site file**, a **hosts entry**, a **database** (if it uses one), and the **app's own settings** pointing at the stack's services. The steps below were run end to end on a real Laravel 12 project (PHP 8.2, then switched to 8.3).

### Which PHP version?

| Upstream (in the nginx file) | PHP | Use for | Status |
|---|---|---|---|
| `php-fpm-74:9000` | 7.4 | legacy apps (e.g. CakePHP 2) | ⚠️ EOL — keep for legacy projects only |
| `php-fpm-81:9000` | 8.1 | older Laravel / Symfony | ⚠️ EOL |
| `php-fpm-82:9000` | 8.2 | Laravel 12, current default | ✅ supported until Dec 2026 |
| `php-fpm-83:9000` | 8.3 | newer projects | ✅ *(optional — start it first)* |

Check the project's `composer.json` (`"php": "..."`) to pick one. Container paths: your `PROJECTS_PATH` folder is mounted at `/var/www`, so `~/code/myapp` on the host is `/var/www/myapp` inside every container.

### 1. Get the code into `PROJECTS_PATH`

New Laravel project, created with the PHP version you chose:

```bash
docker compose exec php-fpm-82 sh -c 'cd /var/www && composer create-project laravel/laravel myapp'
```

Existing project: `git clone` it into `PROJECTS_PATH` on your host, then install its dependencies:

```bash
docker compose exec php-fpm-82 sh -c 'cd /var/www/myapp && composer install'
# private git/composer repos over SSH — run as root (see "macOS vs Linux"):
docker compose exec -u root php-fpm-82 sh -c 'cd /var/www/myapp && composer install'
```

### 2. Add the nginx site

Pick the example that matches the framework, copy it to the top of `nginx/sites/`, and edit the three marked lines:

| Framework | Copy this | Web root inside the container |
|---|---|---|
| Laravel, Symfony | `nginx/sites/examples/laravel.conf` | `/var/www/myapp/public` |
| CakePHP 2, 3, 4, 5 | `nginx/sites/examples/cakephp.conf` | `/var/www/myapp/webroot` |
| WordPress, plain PHP | `nginx/sites/examples/plain-php.conf` | `/var/www/myapp` |

```bash
cp nginx/sites/examples/laravel.conf nginx/sites/myapp.conf
# edit nginx/sites/myapp.conf:
#   server_name  myapp.local;
#   root         /var/www/myapp/public;
#   set $upstream php-fpm-82:9000;
docker compose exec nginx nginx -t              # check the syntax
docker compose exec nginx nginx -s reload       # apply
```

Files in `nginx/sites/*.conf` are local to your machine (git ignores them). More than one hostname can share a site: `server_name myapp.local api.myapp.local;`.

### 3. Add the domain to `/etc/hosts`

```bash
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
```

### 4. Create the database

Open a MySQL shell (it asks for `MYSQL_ROOT_PASSWORD` from your `.env`):

```bash
docker compose exec mysql mysql -uroot -p
```

```sql
CREATE DATABASE myapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'myapp'@'%' IDENTIFIED BY 'choose-a-password';
GRANT ALL PRIVILEGES ON myapp.* TO 'myapp'@'%';
```

To load an existing dump into it (the file stays on your host; works for multi-GB dumps, which can take 20+ minutes):

```bash
docker compose exec -T mysql mysql -uroot -p"YOUR_ROOT_PASSWORD" myapp < ~/Downloads/myapp.sql
```

Dumps that do not contain `CREATE DATABASE` / `USE` lines import into the database you name on the command line.

### 5. Point the app at the stack's services

Inside the containers, use the **service names**, not `localhost`:

| Service | Host | Port | Laravel `.env` |
|---|---|---|---|
| MySQL | `mysql` | `3306` | `DB_CONNECTION=mysql` `DB_HOST=mysql` `DB_DATABASE=myapp` `DB_USERNAME=myapp` `DB_PASSWORD=...` |
| Memcached | `memcached` | `11211` | `CACHE_STORE=memcached` `MEMCACHED_HOST=memcached` |
| Mail (Mailpit catches everything) | `mailhog` | `1025` | `MAIL_MAILER=smtp` `MAIL_HOST=mailhog` `MAIL_PORT=1025` |
| S3 (MinIO, optional) | `minio` | `9000` | endpoint `http://minio:9000` |
| App URL | | | `APP_URL=http://myapp.local` |

Sent mail never leaves your machine — read it at http://localhost:8025. From your **host** (TablePlus, DBeaver) connect to MySQL at `127.0.0.1:3306`.

Then run the app's setup:

```bash
docker compose exec php-fpm-82 sh -c 'cd /var/www/myapp && php artisan migrate'
# Laravel after changing .env:   php artisan config:clear
# CakePHP:   bin/cake migrations migrate        (CakePHP 2: Console/cake ...)
```

Writable folders (Laravel `storage/`, `bootstrap/cache/`; CakePHP `tmp/`, `logs/`) work out of the box on macOS. On Linux, see [www-data & File Permissions](#www-data--file-permissions).

### 6. Check it works

- `http://myapp.local` loads the app.
- `docker compose logs -f nginx php-fpm-82` shows no errors.
- Database: `docker compose exec php-fpm-82 sh -c 'cd /var/www/myapp && php artisan migrate:status'` lists the migrations; an error here means the DB settings are wrong.
- Mail: send one, then open http://localhost:8025.

### Let one site call another by its `.local` name

Inside the containers `myapp.local` does not resolve (your `/etc/hosts` only applies on the host). If a site calls another site server-side — for example a web app calling an API site — give nginx those hostnames as network aliases in a local, git-ignored `docker-compose.override.yml` (Compose loads it automatically):

```yaml
services:
  nginx:
    networks:
      web:
        aliases:
          - myapp.local
          - api.myapp.local
```

```bash
docker compose up -d nginx        # recreates nginx with the aliases
docker compose exec php-fpm-82 getent hosts myapp.local      # should print an address
```

### Switch PHP version later

Change the upstream line in `nginx/sites/myapp.conf` (for example `php-fpm-82:9000` → `php-fpm-83:9000`), then `docker compose exec nginx nginx -s reload`. For PHP 8.3 start the container first: `docker compose --profile optional up -d php-fpm-83`.

### Remove a site

```bash
rm nginx/sites/myapp.conf && docker compose exec nginx nginx -s reload
# remove the line from /etc/hosts, then (optional) drop the database:
#   DROP DATABASE myapp;  DROP USER 'myapp'@'%';
```

### Legacy projects (PHP 7.4, CakePHP 2)

Use `cakephp.conf` with `php-fpm-74:9000`. Things that commonly go wrong:

- **Sessions or login loops:** a malformed cookie domain in the app's `.env` (for example a missing closing quote on `SESSION_DOMAIN`) makes the browser discard the session cookie.
- **"Database connection missing":** the app is still using `localhost`; set the DB host to `mysql`.
- **Debug toolbar crashes on a missing table:** set `DEBUG=0`, or create the table the toolbar asks for.
- **Missing icon fonts:** the PHP images have no `wget`, so installers that call it fail; download the files by hand.

---

## Maintenance & Housekeeping

| Task | Command |
|---|---|
| After a reboot | Docker Desktop starts at login and the containers restart on their own. Check with `docker compose ps` — MySQL can take a few minutes to show `healthy`. |
| Update the service images | `docker compose pull && docker compose up -d` |
| Rebuild a PHP image (Dockerfile change) | `docker compose up -d --build php-fpm-82` |
| See what is using resources | `docker stats --no-stream` |
| Free disk space | `docker image prune` (unused images only) |
| Stop everything, keep data | `docker compose stop` |
| Remove containers, keep data | `docker compose down` |
| ⚠️ Delete everything including databases | `docker compose down -v` — **never** run this without a backup |

MySQL data lives in the `mysql-data` Docker volume — see [Backups](#backups) for dump and restore. Run all commands from the `dev-stack` folder, or use `docker compose -f /path/to/dev-stack/docker-compose.yml ...`.

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
| `MINIO_IMAGE` | `cgr.dev/chainguard/minio:latest` | MinIO image. The official `minio/minio` image is no longer published; the default is a multi-arch (amd64 + arm64) build. Override to use your own. |
| `SSH_AUTH_SOCK_HOST` | _(your shell's `SSH_AUTH_SOCK`)_ | Host ssh-agent socket forwarded into the PHP containers (for `composer install` from private git repos). **macOS: set to `/run/host-services/ssh-auth.sock`.** |
| `NGINX_HTTP_PORT` | `80` | HTTP port. Keep as `80` so `.local` domains work in the browser without specifying a port. |
| `NGINX_HTTPS_PORT` | `443` | HTTPS port. |
| `ADMINER_PORT` | `8081` | Adminer web UI port. Open `http://localhost:8081`. |
| `ADMINER_DEFAULT_SERVER` | `mysql` | MySQL hostname Adminer connects to by default. Keep as `mysql` (Docker service name). |

> File ownership inside the containers is covered in [www-data & File Permissions](#www-data--file-permissions).

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

PHP-FPM runs as `www-data` (UID/GID `1000`) inside the containers.

- **macOS (Docker Desktop):** nothing to configure. Files PHP creates in your projects show up owned by you.
- **Linux:** the default `1000:1000` matches most single-user machines. If `id -u` / `id -g` on your host are something else, add `UID=<id -u>` and `GID=<id -g>` to `.env` and rebuild (`docker compose build php-fpm-XX`) so `www-data` is remapped to you. Do not `export UID=...` in zsh — it is read-only there.

If you still see permission errors on project files:

```bash
sudo chown -R $USER ~/projects
```

---

## Commands Reference

### When to `build` vs `up` vs `restart`

> Replace `php-fpm-XX` with the PHP version your project needs e.g. `php-fpm-82`. Only build what you need — EOL versions may have build issues.

| Situation | Command |
|-----------|---------|
| First time setup | `docker compose build php-fpm-XX && docker compose up -d` |
| Changed a `Dockerfile` (added extension, package) | `docker compose up -d --build php-fpm-XX` |
| Changed `docker-compose.yml` (ports, volumes, env) | `docker compose up -d` |
| Changed an Nginx `.conf` site file | `docker compose exec nginx nginx -s reload` |
| Changed `nginx/nginx.conf` | `docker compose restart nginx` |
| Changed `.env` values | `docker compose up -d` |
| Service crashed or misbehaving | `docker compose restart php-fpm-XX` |
| Just starting your workday | `docker compose up -d` |
| Shutting down | `docker compose down` |
| Shutting down and wiping DB data | `docker compose down -v` ⚠️ deletes volumes |

> **Rule of thumb:** Use `--build` only when a `Dockerfile` changes. Everything else is `up -d` or `restart`.

---

### Stack

```bash
# Start all services in background
docker compose up -d

# Start only specific services
docker compose up -d nginx mysql php-fpm-XX

# Start the optional service
docker compose up -d php-fpm-83

# Stop all services (keeps data volumes intact)
docker compose down

# Stop and remove all volumes (wipes MySQL, MinIO data) ⚠️
docker compose down -v

# Check status of all containers
docker compose ps

# Show live CPU/memory usage per container
docker stats

# View all images built
docker images

# Remove unused images to free disk space
docker image prune -a
```

### Build

> **Important:** Do NOT run `docker compose build` without specifying a service — this builds ALL PHP versions including EOL ones. Only build the PHP version(s) your projects actually need.

```bash
# Build a specific PHP version only (recommended)
docker compose build php-fpm-XX

# Build and start a specific version
docker compose up -d --build php-fpm-XX

# Build multiple specific versions
docker compose build php-fpm-81 php-fpm-82

# Force rebuild from scratch ignoring cache (e.g. after base image update)
docker compose build --no-cache php-fpm-XX

# Build ALL images — only do this if you need every PHP version ⚠️
docker compose build
```

### Restart

```bash
# Restart a single service (keeps container, fast)
docker compose restart nginx

# Restart multiple services
docker compose restart nginx php-fpm-XX

# Full restart of everything
docker compose down && docker compose up -d

# Apply docker-compose.yml changes (ports, volumes, env vars)
docker compose up -d          # compose detects changes and recreates affected containers
```

### Logs

```bash
# Tail all service logs
docker compose logs -f

# Tail logs for a specific service
docker compose logs -f nginx
docker compose logs -f php-fpm-XX
docker compose logs -f mysql

# Show last 100 lines then follow
docker compose logs --tail=100 -f nginx

# Show logs without following (useful for quick checks)
docker compose logs nginx
```

### PHP

```bash
# Open an interactive shell inside a PHP container
docker compose exec php-fpm-XX bash

# Run Composer install
docker compose exec php-fpm-XX composer install -d /var/www/myproject

# Run Composer update
docker compose exec php-fpm-XX composer update -d /var/www/myproject

# Run Laravel Artisan commands
docker compose exec php-fpm-XX php /var/www/myproject/artisan migrate
docker compose exec php-fpm-XX php /var/www/myproject/artisan migrate:fresh --seed
docker compose exec php-fpm-XX php /var/www/myproject/artisan cache:clear
docker compose exec php-fpm-XX php /var/www/myproject/artisan queue:work

# Check PHP version
docker compose exec php-fpm-XX php -v

# List all loaded PHP extensions
docker compose exec php-fpm-XX php -m

# Show active php.ini files
docker compose exec php-fpm-XX php --ini

# Check a specific config value
docker compose exec php-fpm-XX php -r "echo ini_get('upload_max_filesize');"

# Run a PHP script directly
docker compose exec php-fpm-XX php /var/www/myproject/script.php
```

### Nginx

```bash
# Open a shell in Nginx container
docker compose exec nginx sh

# Test nginx config for syntax errors (always do this before reload)
docker compose exec nginx nginx -t

# Reload nginx after adding/editing a site config (zero downtime)
docker compose exec nginx nginx -s reload

# Hard restart nginx (use if reload doesn't pick up changes)
docker compose restart nginx

# View live access log
docker compose exec nginx tail -f /var/log/nginx/access.log

# View live error log (check here when a site returns 502/504)
docker compose exec nginx tail -f /var/log/nginx/error.log
```

### MySQL

```bash
# Open MySQL shell as root
docker compose exec mysql mysql -u root -p

# Create a new database
docker compose exec mysql mysql -u root -p -e "CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# List all databases
docker compose exec mysql mysql -u root -p -e "SHOW DATABASES;"

# Import a SQL dump into a database
docker compose exec -T mysql mysql -u root -p mydb < /path/to/dump.sql

# Export (dump) a database to a file
docker compose exec mysql mysqldump -u root -p mydb > /path/to/dump.sql

# Export all databases
docker compose exec mysql mysqldump -u root -p --all-databases > all-databases.sql

# Check MySQL status
docker compose exec mysql mysqladmin -u root -p status
```

### Memcached

```bash
# Check Memcached stats (hit rate, memory usage, connections)
docker compose exec memcached sh -c "echo stats | nc localhost 11211"

# Flush all cached data
docker compose exec memcached sh -c "echo flush_all | nc localhost 11211"
```

### MinIO

```bash
# Open a shell in MinIO
docker compose exec minio sh

# One-time: register the server under the name "local" (uses the credentials from your .env)
docker compose exec minio sh -c 'mc alias set local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"'

# List buckets
docker compose exec minio mc ls local

# Create a bucket
docker compose exec minio mc mb local/mybucket
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

> **MySQL 8.0 reached end-of-life in April 2026.** It is still what the stack runs, because changing the major version of an existing data volume is one-way. To move to 8.4 LTS, take a backup first (below), then change `image: mysql:8.0` in `docker-compose.yml`. Applications that rely on `mysql_native_password` need extra configuration on 8.4.

### Shutdown, health and memory

- `stop_grace_period: 3m` gives InnoDB time to flush and shut down cleanly. A kill after Docker's default 10 seconds forces crash recovery (minutes on a large database) on the next start.
- The container has a health check; `docker compose ps` shows `healthy` once MySQL accepts connections. After an unclean shutdown it can take several minutes.
- `mysql/my.cnf` sizes `innodb_buffer_pool_size` for 6 GB of Docker memory. Raise it if you give Docker more.

### Backups

Databases live in the `mysql-data` Docker volume. `docker compose down -v`, a Docker Desktop reset, or removing the volume deletes them, so keep dumps of anything you can't re-create:

```bash
# back up one database
docker compose exec -T mysql mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines mydb > mydb.sql

# restore (create the database first)
docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS mydb"
docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" mydb < mydb.sql
```

## MinIO

- API endpoint: `http://localhost:9000`
- Web console: `http://localhost:9001`
- Credentials: `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `.env`

In your app config, set the S3 endpoint to:
- `http://minio:9000` — when connecting from inside a container
- `http://localhost:9000` — when connecting from your host machine

## Performance Tuning

### PHP-FPM Pool Size

The default `pm.max_children = 5` limits concurrent PHP requests to 5. For a dev machine with 16GB RAM this causes request queuing under normal use.

Each PHP-FPM container includes a `zz-pm.conf` that overrides the pool settings:

```ini
pm = dynamic
pm.max_children = 20
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 6
pm.max_requests = 500
```

`pm.max_requests = 500` recycles workers after 500 requests, preventing memory leaks from accumulating over a long dev session.

To verify the settings are active:

```bash
docker compose exec php-fpm-74 php-fpm -tt 2>&1 | grep pm
```

### Docker Daemon Config

`daemon.json` at the repo root should be copied to `/etc/docker/daemon.json` on the host:

```bash
sudo cp daemon.json /etc/docker/daemon.json && sudo systemctl reload docker
```

What it does:
- **BuildKit** — faster, parallelised image builds with better layer caching
- **Log rotation** — caps container logs at 10MB x 3 files, preventing disk fill-over over time

### wkhtmltopdf — Patched Qt Build

PHP 7.4 and 8.1 install `wkhtmltopdf 0.12.6.1 (with patched qt)` from GitHub releases rather than the Debian apt package. The patched Qt build supports full CSS rendering (box-shadow, flexbox, etc.) required for PDF generation. Both `wkhtmltopdf` and `wkhtmltoimage` are installed at `/usr/local/bin/`.

The Debian apt package (`0.12.6` without patched Qt) does not support these CSS features and will produce broken PDFs.

---

## Troubleshooting

**Site shows 502 Bad Gateway**
- The PHP container isn't running. Check: `docker compose ps`
- Check PHP logs: `docker compose logs -f php-fpm-XX`
- Make sure the `set $upstream` in your nginx site config matches a running container name

**Permission denied on project files**
- Run: `sudo chown -R $USER:$USER ~/projects`
- On Linux with a user that is not `1000:1000`, set `UID`/`GID` in `.env` and rebuild (see [www-data & File Permissions](#www-data--file-permissions))

**Port already in use**
- Change the port in `.env` then run `docker compose up -d`
- Find what's using it: `sudo lsof -i :80`

**Container won't start**
- Check logs: `docker compose logs php-fpm-XX`
- Try a full restart: `docker compose down && docker compose up -d`

**php-fpm-83 not starting with `docker compose up -d`**
- This is an optional service excluded by default. Start it manually: `docker compose up -d php-fpm-83`

**Changes to `.env` not taking effect**
- Run `docker compose up -d` — Compose will recreate affected containers with the new values

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
docker compose build php-fpm-82
docker compose up -d --build php-fpm-82
```

Verify it loaded:

```bash
docker compose exec php-fpm-82 php -m | grep bcmath
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
docker compose build php-fpm-82
docker compose exec php-fpm-82 php -m | grep redis
```

---

### Changing PHP ini Settings

PHP settings (`upload_max_filesize`, `memory_limit`, `max_execution_time`, etc.) are configured by dropping a `.ini` file into `/usr/local/etc/php/conf.d/` inside the container.

#### Option 1: Shared volume mount (current setup — no rebuild needed)

`php.ini` at the repo root is mounted into all PHP-FPM containers via `docker-compose.yml`:

```yaml
volumes:
  - ./php.ini:/usr/local/etc/php/conf.d/custom.ini
```

Edit `php.ini` on the host and restart the container:

```bash
docker compose restart php-fpm-74
```

#### Option 2: Bake into the image via Dockerfile

Add a `RUN` line in the relevant Dockerfile:

```dockerfile
RUN echo "upload_max_filesize = 256M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "post_max_size = 256M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/custom.ini
```

Then rebuild:

```bash
docker compose build php-fpm-82 && docker compose up -d php-fpm-82
```

#### Verify

```bash
docker compose exec php-fpm-74 php -r "echo ini_get('memory_limit');"
# or check all active ini files
docker compose exec php-fpm-74 php --ini
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
docker compose restart mysql
```

Verify the setting took effect:

```bash
docker compose exec mysql mysql -u root -p -e "SHOW VARIABLES LIKE 'max_connections';"
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

> Bullseye is end-of-life (and `php:7.4` has no Bookworm variant). Each Dockerfile starts with a step that points apt at `archive.debian.org`.

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

**`ARG`** — declares a build-time variable with an optional default. These values are injected when `docker compose build` runs, from the `args:` block in `docker-compose.yml`. They are only available during the build — not at container runtime.

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

**`WORKDIR`** — sets the default working directory inside the container. Any shell opened with `docker compose exec php-fpm-XX bash` starts here. Also the directory where Composer and PHP commands run by default when no path is specified.

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

Declares **named volumes** — Docker-managed storage that persists across container restarts and `docker compose down`. Unlike bind mounts (which point to a folder on your host), named volumes are managed by Docker and stored internally under `/var/lib/docker/volumes/`.

- `mysql-data` — stores MySQL database files; survives restarts
- `minio-data` — stores MinIO object data (buckets and uploaded files); survives restarts
- `memcached-data` — declared at the top level but not mounted to the memcached service; effectively unused. Memcached is inherently ephemeral — cache is always lost on restart.

> **Warning:** `docker compose down -v` deletes all named volumes — including your MySQL data. Do not use `-v` unless you intend to wipe the database.

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

Profiles mark services as opt-in. Services with a profile are **excluded from `docker compose up -d`** by default — they only start when explicitly named or when the profile is activated. PHP 8.3 uses the `optional` profile.

```bash
docker compose up -d php-fpm-83    # start a specific optional service
```

Services without `profiles:` always start with `docker compose up -d`.

---

### Per-service: restart

```yaml
restart: always
```

Tells Docker to restart the container automatically if it exits — whether due to a crash, an error, or the Docker daemon restarting (e.g., after a machine reboot). Most services use `always` so the dev stack comes back without manual intervention.

MinIO and PHP 8.3 use `restart: "no"` — they do not start automatically on daemon restart. Start them manually when needed:

```bash
docker compose up -d minio
docker compose up -d php-fpm-83
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
| Named volume | `volume-name:/container/path` | Docker manages the storage. Persists across `docker compose down`, deleted by `docker compose down -v`. |
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
