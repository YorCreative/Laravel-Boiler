FROM php:8.4-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    git \
    unzip \
    openssl \
    libc6-dev \
    libssl-dev \
    libicu-dev \
    zlib1g-dev \
    g++ \
    curl \
    gcc \
    make \
    autoconf \
    pkg-config \
    libcurl4-openssl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip intl

# Install Redis PHP extension (latest stable version)
RUN pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /tmp/pear

# Install Node.js, npm, and npx
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get update && apt-get install -y nodejs dnsutils \
    && npm install -g npm@latest npx@latest \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Get latest Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www
RUN git config --global --add safe.directory /var/www
# Copy init.sh into container
COPY docker/utility/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

# Set permissions
RUN chown -R www-data:www-data /var/www

# Expose port 9000
EXPOSE 9000

# Run init.sh and then start php-fpm
CMD ["/bin/sh", "-c", "/usr/local/bin/init.sh && php-fpm"]
