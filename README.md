# Deploying Laravel with Octane + FrankenPHP on Sevalla

Sevalla works with Docker. Therefore, this repository includes a [Dockerfile](/Dockerfile) that packages a Laravel application and runs it.

## Architecture

On Sevalla, every app has a **default web process** that serves HTTP requests. In this example, the app is built from the repository’s `Dockerfile`, and the web process runs a single service:

- **FrankenPHP (Laravel Octane)**: listens on `localhost:8080` and serves your Laravel app.

The start command is in [entrypoint.sh](/entrypoint.sh), which launches Octane with FrankenPHP.

## Steps

### 1. Prepare your repository

Copy this repository’s `Dockerfile` and `entrypoint.sh` files into the **root** of your Laravel project. Or just clone this repository if you are starting from scratch.

### 2. Create Sevalla resources

1. [Create a **database**](https://app.sevalla.com/databases).

2. [Create a **new application**](https://app.sevalla.com/apps/new) and connect your repository (don't deploy it yet).

### 3. Configure the Sevalla app

#### A. Create a process to run DB migrations

1. Go to **App → Processes** and create a **Job** process.
2. Set the start command to:

   ```bash
   php artisan migrate --force
   ```

<img width="540" src="https://github.com/user-attachments/assets/7af80896-c431-4cd4-b5f0-5034b2c65d23" />

#### B. Allow internal connections between the app and database

1. Go to **App → Networking** and scroll to **Connected services**.
2. Click **Add connection**, select the database you created, and enable **Add environment variables to the application** in the modal.

#### C. Set environment variables

Set the following in **App → Environment variables**. Fill in any empty values for your setup.

**Notes:**
- Set `DB_CONNECTION` with the value matching the database you created in step **B**. E.g., `mysql` or `pgsql`.
- `DB_URL` is automatically added if you completed step **B**.
- **Set `APP_URL` and `ASSET_URL` to your Sevalla app URL (e.g., `https://your-app.sevalla.app` or your custom domain).**
- Ensure `APP_KEY` is set (e.g., via `php artisan key:generate`).
- In production, keep `APP_DEBUG` to `false`.

#### D. Start the scheduler

1. Go to **App → Processes → Create process → Background worker**.
2. Set the custom start command to `php artisan schedule:work`.

<img width="540" height="1152" src="https://github.com/user-attachments/assets/78224eac-66d0-4a49-b128-4087a31b37b5" />

#### E. Start your default queue

1. Go to **App → Processes → Create process → Background worker**.
2. Set the custom start command to `php artisan queue:work`.

#### F. Switch to Dockerfile-based build

Go to **App → Settings → Build** and change **Build environment** to **Dockerfile**.

<img width="473" src="https://github.com/user-attachments/assets/b074529e-3f51-471d-aa89-9a585dda2e5a" />

### 4. Deploy 🚀

Trigger a new deployment from Sevalla. Once deployed, your Laravel app will run inside the web process on Octane + FrankenPHP.

## Runtime architecture

- Octane server: **FrankenPHP** (single binary HTTP server + PHP runtime)
- PHP version: from image tag (currently `php8.4`)
- Build steps: Composer install (no dev), Vite build, copy into FrankenPHP image
- Health endpoint: `GET /up` (built-in in Laravel 12 via `bootstrap/app.php`)

## Files

- `Dockerfile`: multi-stage build. Final stage uses `dunglas/frankenphp` and runs `php artisan octane:start --server=frankenphp`.
- `entrypoint.sh`: starts Octane with sane defaults and accepts env overrides.
- `public/frankenphp-worker.php`: boots the Octane FrankenPHP worker.
- `config/octane.php`: default server set to `frankenphp`.

## Required env vars

Set these in Sevalla → App → Environment variables:

- `APP_ENV=production`
- `APP_DEBUG=false`
- `APP_KEY` (generate locally via `php artisan key:generate`)
- `APP_URL` and `ASSET_URL` pointing to your Sevalla URL
- `DB_URL` (auto-added if you connect your Sevalla database) or the usual `DB_*` vars
- Optional Octane tuning:
  - `PORT` (defaults 8080 on container)
  - `ADMIN_PORT` (defaults 2019)
  - `OCTANE_WORKERS` (e.g., `auto`, `2`, `4`)
  - `OCTANE_MAX_REQUESTS` (default `500`)
  - `OCTANE_MAX_EXECUTION_TIME` (default `30`)

## Notes and tips

- The Dockerfile installs common PHP extensions via `install-php-extensions` (e.g., `intl`, `mbstring`, `pdo_mysql`, `opcache`, `zip`, `redis`). Add more as your app needs.
- The image exposes port `8080`. Sevalla maps this to your public URL.
- Octane best practices: avoid singletons with request-specific state; monitor for memory leaks. See the official docs: [Laravel Octane → Serving your application](https://laravel.com/docs/12.x/octane#serving-your-application).
