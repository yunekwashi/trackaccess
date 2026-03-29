FROM php:8.2-apache

# Install mysqli extension for PHP to interact with MySQL
RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

# Copy the backend files to the container
COPY . /var/www/html/

# Ensure permissions are correct
RUN chown -R www-data:www-data /var/www/html
