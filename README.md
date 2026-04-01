# Docker Dev Environment

Local development stack with Nginx, MySQL, multiple PHP-FPM versions, Memcached, MinIO, and Adminer.

## Services

| Service    | Description                        | Default Port |
|------------|------------------------------------|--------------|
| Nginx      | Web server / reverse proxy         | 80, 443      |
| PHP 7.1    | PHP-FPM 7.1                        | -            |
| PHP 7.4    | PHP-FPM 7.4                        | -            |
| PHP 8.0    | PHP-FPM 8.0                        | -            |
| PHP 8.1    | PHP-FPM 8.1                        | -            |
| PHP 8.2    | PHP-FPM 8.2                        | -            |
| PHP 8.3    | PHP-FPM 8.3                        | -            |
| MySQL 8.0  | Database                           | 3306         |
| Memcached  | Cache                              | 11211        |
| MinIO      | S3-compatible object storage       | 9000         |
| MinIO UI   | MinIO web console                  | 9001         |
| Adminer    | Database management UI             | 8081         |
| phpMyAdmin | Database management UI             | 8082         |

## Requirements

- Docker
- Docker Compose

## Port Configuration

All ports are configured in `.env`. If a port is already in use on your machine, change it there:

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

To check which process is using a port:

```bash
sudo lsof -i :80
sudo ss -tulnp | grep :3306
```

## Global Alias (Optional)

To run docker commands from any directory without `cd`-ing into the repo, add this alias to your `~/.bashrc` or `~/.zshrc`:

```bash
alias dc="docker compose -f $HOME/projects/dev-stack/docker-compose.yml"
```

Then reload your shell:

```bash
source ~/.bashrc
```

Now you can use `dc` from anywhere:

```bash
dc up -d
dc down
dc logs -f nginx
dc exec php-fpm-83 bash
dc restart nginx
```

## Setup

### 1. Clone the repo

```bash
git clone git@github.com:parasBisht/dev-stack.git
cd dev-stack
```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and fill in your values:

```env
PROJECTS_PATH=~/projects        # path to your projects folder on the host

MYSQL_ROOT_PASSWORD=secret      # MySQL root password

MINIO_ROOT_USER=minio           # MinIO username
MINIO_ROOT_PASSWORD=minio123    # MinIO password
```

### 3. Build and start

```bash
docker compose up -d
```

To rebuild images (e.g. after changing a Dockerfile):

```bash
docker compose up -d --build
```

### 4. Add local domain to /etc/hosts

For each project you add, map its domain to localhost:

```bash
echo "127.0.0.1 myproject.local" | sudo tee -a /etc/hosts
```

## Adding a New Project

### 1. Create an Nginx site config

Sample configs are in `nginx/sites/examples/` — copy one as a starting point:

```bash
cp nginx/sites/examples/example.conf nginx/sites/myproject.conf
```

Then edit `nginx/sites/myproject.conf`:

```nginx
server {
    listen 80;
    server_name myproject.local;
    root /var/www/myproject/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ \.php$ {
        try_files $uri =404;
        set $upstream php-fpm-83:9000;   # change PHP version here
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

Supported PHP upstream values: `php-fpm-71:9000`, `php-fpm-74:9000`, `php-fpm-80:9000`, `php-fpm-81:9000`, `php-fpm-82:9000`, `php-fpm-83:9000`

### 2. Reload Nginx

```bash
docker compose exec nginx nginx -s reload
```

### 3. Add the domain to /etc/hosts

```bash
echo "127.0.0.1 myproject.local" | sudo tee -a /etc/hosts
```

Your project is now accessible at `http://myproject.local`.

## Common Commands

### Stack

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# Restart a service
docker compose restart nginx

# Rebuild a specific service after Dockerfile changes
docker compose up -d --build php-fpm-83

# Check running containers and status
docker compose ps

# Show resource usage
docker stats
```

### Logs

```bash
# Tail all logs
docker compose logs -f

# Tail logs for a specific service
docker compose logs -f nginx
docker compose logs -f php-fpm-83
docker compose logs -f mysql

# Last 100 lines
docker compose logs --tail=100 nginx
```

### PHP

```bash
# Open a shell in a PHP container
docker compose exec php-fpm-83 bash

# Run Composer
docker compose exec php-fpm-83 composer install -d /var/www/myproject
docker compose exec php-fpm-83 composer update -d /var/www/myproject

# Run an Artisan command (Laravel)
docker compose exec php-fpm-83 php /var/www/myproject/artisan migrate

# Check PHP version
docker compose exec php-fpm-83 php -v

# Check loaded PHP extensions
docker compose exec php-fpm-83 php -m

# Check active PHP config
docker compose exec php-fpm-83 php --ini

# Run a PHP script
docker compose exec php-fpm-83 php /var/www/myproject/script.php
```

### Nginx

```bash
# Open a shell in Nginx
docker compose exec nginx sh

# Test Nginx config for errors
docker compose exec nginx nginx -t

# Reload Nginx after config changes
docker compose exec nginx nginx -s reload

# View Nginx access log
docker compose exec nginx tail -f /var/log/nginx/access.log

# View Nginx error log
docker compose exec nginx tail -f /var/log/nginx/error.log
```

### MySQL

```bash
# Open MySQL shell
docker compose exec mysql mysql -u root -p

# Import a SQL dump
docker compose exec -T mysql mysql -u root -p mydb < dump.sql

# Export a database
docker compose exec mysql mysqldump -u root -p mydb > dump.sql

# Create a new database
docker compose exec mysql mysql -u root -p -e "CREATE DATABASE mydb;"

# List all databases
docker compose exec mysql mysql -u root -p -e "SHOW DATABASES;"
```

### Memcached

```bash
# Check Memcached stats
docker compose exec memcached sh -c "echo stats | nc localhost 11211"
```

### MinIO

```bash
# Open a shell in MinIO
docker compose exec minio sh

# List buckets (using mc CLI inside container)
docker compose exec minio mc ls local
```

## MySQL

Connect from your host machine:

- Host: `127.0.0.1`
- Port: `3306`
- User: `root`
- Password: value of `MYSQL_ROOT_PASSWORD` in `.env`

Or use **Adminer** at `http://localhost:8081`.

## MinIO

- API: `http://localhost:9000`
- Console: `http://localhost:9001`
- Credentials: `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `.env`

In your app, set the S3 endpoint to `http://minio:9000` (inside Docker network) or `http://localhost:9000` (from host).
