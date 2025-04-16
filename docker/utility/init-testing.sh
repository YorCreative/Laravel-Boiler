#!/bin/sh

cd "$GITHUB_WORKSPACE"

composer install

npm install

# Check if .env exists, if not copy .env.example and generate key
if [ ! -f .env ]; then
    cp .env.example .env

    sed -i 's/DB_HOST=.*/DB_HOST=127.0.0.1/' .env
    sed -i 's/DB_PORT=.*/DB_PORT=3306/' .env
    sed -i 's/DB_DATABASE=.*/DB_DATABASE=laravel_boiler/' .env
    sed -i 's/DB_USERNAME=.*/DB_USERNAME=root/' .env
    sed -i 's/DB_PASSWORD=.*/DB_PASSWORD=secret/' .env

    php artisan key:generate

    php artisan migrate

    php artisan migrate --database="testing-mysql"
fi

php artisan migrate

