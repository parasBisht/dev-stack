FROM php:7.4-fpm-bullseye

# Package sources:
#   apt packages  → official Debian Bullseye repos (deb.debian.org)
#   wkhtmltopdf   → GitHub releases (wkhtmltopdf/packaging) — patched Qt build with full CSS support
#   memcached ext → PECL (pecl.php.net) — PHP official extension registry
#   composer      → official composer Docker image (hub.docker.com/_/composer)

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    xfonts-75dpi \
    xfonts-base \
    fontconfig \
    libxrender1 \
    libxext6 \
    && curl -fsSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bullseye_amd64.deb -o /tmp/wkhtmltox.deb \
    && apt-get install -y /tmp/wkhtmltox.deb \
    && rm /tmp/wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
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
    && groupmod -g ${GID} ${FPM_GROUP}

WORKDIR ${WORKDIR}

USER www-data
