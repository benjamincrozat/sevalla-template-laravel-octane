## Multi-stage Dockerfile for Laravel Octane (FrankenPHP) on Sevalla
#
# Intent
# - Serve a Laravel 12 app with Octane on FrankenPHP (no Nginx / PHP-FPM needed)
# - Split build into stages to maximize cache hits and produce a minimal runtime
# - Build Composer deps and Vite assets outside the final image
# - Ship production-safe defaults suitable for small containers on Sevalla
# - Provide a container-native healthcheck and tunable Octane worker settings
# - Reference: Laravel Octane “Serving Your Application” docs:
#   https://laravel.com/docs/12.x/octane#serving-your-application
#
# Stages overview
# 1) vendor  : Composer install (no dev) → produces ./vendor
# 2) assets  : Node/Vite build            → produces ./public/build
# 3) runtime : FrankenPHP + Octane entry  → copies app, vendor, assets

# Stage 1: PHP dependencies (Composer)
# Only copy composer manifests first to leverage Docker cache; install prod deps.
FROM composer:2 AS vendor
WORKDIR /app

COPY composer.json composer.lock ./
# Install production dependencies only; skip scripts and platform checks since
# required extensions are provided by the runtime stage.
RUN composer install --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader --no-scripts --ignore-platform-reqs

# Stage 2: Frontend assets (Vite / Node)
# Install Node deps reproducibly via lockfile and build Vite assets → public/build
FROM node:24-alpine AS assets
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 3: Final runtime with FrankenPHP (Octane server)
# Choose a FrankenPHP image matching PHP >= 8.2 (composer.json requires ^8.2)
FROM dunglas/frankenphp:1.3-php8.4-alpine AS runtime

# Production defaults and Octane server selection. FRANKENPHP_CONFIG registers
# the Octane worker script so FrankenPHP can boot the Laravel application.
ENV APP_ENV=production \
    APP_DEBUG=false \
    OCTANE_SERVER=frankenphp \
    FRANKENPHP_CONFIG="worker ./public/frankenphp-worker.php"

WORKDIR /app

# System dependencies commonly needed by PHP extensions and Laravel.
RUN apk add --no-cache bash tzdata icu-dev oniguruma-dev libzip-dev libpng-dev libjpeg-turbo-dev freetype-dev

# Install PHP extensions via the community installer (mlocati).
# Keep the list minimal and aligned with your app to reduce image size.
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN install-php-extensions bcmath gd intl mbstring pdo_mysql opcache zip redis

# Copy application source code.
COPY . .

# Copy optimized vendor directory and built front-end assets from build stages.
COPY --from=vendor /app/vendor ./vendor
COPY --from=assets /app/public/build ./public/build

# Ensure writable directories exist and permissions are correct for Laravel.
RUN mkdir -p storage bootstrap/cache && \
    chown -R www-data:www-data storage bootstrap/cache && \
    chmod -R ug+rwx storage bootstrap/cache

# Optional: ensure a default .env exists at build time (useful for first boot).
RUN [ -f .env ] || ( [ -f .env.example ] && cp .env.example .env ) || true

# FrankenPHP serves HTTP directly; Sevalla maps $PORT to this container port.
EXPOSE 8080

# Container healthcheck using Laravel 12 built-in health endpoint `/up`.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s CMD wget -qO- http://127.0.0.1:${PORT:-8080}/up || exit 1

# Entrypoint launches Octane with FrankenPHP (see entrypoint.sh).
RUN chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
