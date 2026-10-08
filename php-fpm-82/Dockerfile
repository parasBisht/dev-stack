FROM php:8.2-fpm-bullseye

# bullseye is EOL: use the Debian archive for apt
RUN sed -i -e "s|deb.debian.org|archive.debian.org|g" -e "s|security.debian.org|archive.debian.org|g" -e "/bullseye-updates/d" /etc/apt/sources.list \
    && echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf.d/99archive


# Package sources:
#   apt packages  → official Debian Bullseye repos (deb.debian.org)
#   wkhtmltopdf   → official Debian Bullseye repo (abandoned upstream, still packaged in Debian)
#   memcached ext → PECL (pecl.php.net) — PHP official extension registry
#   composer      → official composer Docker image (hub.docker.com/_/composer)
# Note: Bookworm dropped libmemcached-dev — using Bullseye which has both wkhtmltopdf and libmemcached-dev

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
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
    && mkdir -p /tmp/memcached && curl -fsSL https://github.com/php-memcached-dev/php-memcached/archive/refs/tags/v3.3.0.tar.gz | tar xz -C /tmp/memcached --strip-components=1 \
    && cd /tmp/memcached && phpize && ./configure && make -j"$(nproc)" && make install && cd / && rm -rf /tmp/memcached \
    && docker-php-ext-enable memcached \
    && mkdir -p /tmp/apcu && curl -fsSL https://github.com/krakjoe/apcu/archive/refs/tags/v5.1.24.tar.gz | tar xz -C /tmp/apcu --strip-components=1 \
    && cd /tmp/apcu && phpize && ./configure && make -j"$(nproc)" && make install && cd / && rm -rf /tmp/apcu \
    && docker-php-ext-enable apcu \
    && apt-get purge -y g++ make autoconf \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Node.js + bower (required for front-end asset management)
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm \
    && npm install -g bower \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000
ARG WORKDIR=/var/www
RUN FPM_USER=$(grep -E '^\s*user\s*=' /usr/local/etc/php-fpm.d/www.conf | sed 's/.*=\s*//;s/\s*//g') \
    && FPM_GROUP=$(grep -E '^\s*group\s*=' /usr/local/etc/php-fpm.d/www.conf | sed 's/.*=\s*//;s/\s*//g') \
    && usermod -u ${UID} ${FPM_USER} \
    && groupmod -o -g ${GID} ${FPM_GROUP}

WORKDIR ${WORKDIR}

USER www-data
