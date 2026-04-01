FROM php:7.1-fpm

# Package sources:
#   apt packages  → archive.debian.org (Buster is EOL, redirected from deb.debian.org)
#   wkhtmltopdf   → official Debian Buster archive (abandoned upstream, still packaged in Debian)
#   memcached ext → PECL (pecl.php.net) — PHP official extension registry
#   composer      → official composer Docker image (hub.docker.com/_/composer)

# Debian Buster (used by php:7.1-fpm) is EOL — redirect to archive and drop security/updates repos
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i '/security/d' /etc/apt/sources.list \
    && sed -i '/buster-updates/d' /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    wkhtmltopdf \
    libmemcached-dev \
    libzip-dev \
    libpng-dev \
    libxml2-dev \
    libicu-dev \
    zlib1g-dev \
    libonig-dev \
    pkg-config \
    g++ \
    make \
    autoconf \
    && docker-php-ext-install \
        pdo_mysql \
        mysqli \
        mbstring \
        xml \
        zip \
        gd \
        intl \
        opcache \
    && pecl install memcached \
    && docker-php-ext-enable memcached \
    && apt-get purge -y g++ make autoconf \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

ARG UID=1000
ARG GID=1000
ARG WORKDIR=/var/www
RUN FPM_USER=$(grep -E '^\s*user\s*=' /usr/local/etc/php-fpm.d/www.conf | sed 's/.*=\s*//;s/\s*//g') \
    && FPM_GROUP=$(grep -E '^\s*group\s*=' /usr/local/etc/php-fpm.d/www.conf | sed 's/.*=\s*//;s/\s*//g') \
    && usermod -u ${UID} ${FPM_USER} \
    && groupmod -g ${GID} ${FPM_GROUP}

WORKDIR ${WORKDIR}
