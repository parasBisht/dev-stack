# Docker Dev Environment

Local development stack with Nginx, MySQL, multiple PHP-FPM versions, Memcached, MinIO, and Adminer.

## Services

| Service    | Description                        | Default Port |
|------------|------------------------------------|--------------|
| Nginx      | Web server / reverse proxy         | 80, 443      |
| PHP 7.1    | PHP-FPM 7.1                        | -            |
| PHP 7.4    | PHP-FPM 7.4                        | -            |
| PHP 8.1    | PHP-FPM 8.1                        | -            |
| PHP 8.2    | PHP-FPM 8.2                        | -            |
| PHP 8.3    | PHP-FPM 8.3                        | -            |
| MySQL 8.0  | Database                           | 3306         |
| Memcached  | Cache                              | 11211        |
| MinIO      | S3-compatible object storage       | 9000         |
| MinIO UI   | MinIO web console                  | 9001         |
| Adminer    | Database management UI             | 8081         |

## Requirements

- Docker
- Docker Compose

## Setup

### 1. Clone the repo

```bash
git clone git@github.com:YOUR_USERNAME/docker-setup.git
cd docker-setup
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

Create a file in `nginx/sites/myproject.conf`:

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

Supported PHP upstream values: `php-fpm-71:9000`, `php-fpm-74:9000`, `php-fpm-81:9000`, `php-fpm-82:9000`, `php-fpm-83:9000`

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

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# View logs
docker compose logs -f

# View logs for a specific service
docker compose logs -f nginx

# Restart a service
docker compose restart nginx

# Rebuild a specific service
docker compose up -d --build php-fpm-83

# Open a shell in a container
docker compose exec php-fpm-83 bash

# Run Composer inside a container
docker compose exec php-fpm-83 composer install -d /var/www/myproject
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
