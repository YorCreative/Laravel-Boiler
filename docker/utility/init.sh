#!/bin/sh

cd /var/www

composer install

npm install

# Check if .env exists, if not copy .env.example and generate key
if [ ! -f .env ]; then
    cp .env.example .env
    php artisan key:generate

    php artisan horizon:install

    php artisan migrate --database="testing-mysql"
fi

php artisan migrate

