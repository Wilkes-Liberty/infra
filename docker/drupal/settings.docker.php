<?php

/**
 * @file
 * Docker environment settings for WilkesLiberty Drupal.
 *
 * This file is installed as web/sites/default/settings.local.php.
 * It configures Drupal using environment variables injected by Docker Compose.
 *
 * In production: copied into the image by Dockerfile.prod
 * In development: mounted as a read-only volume by docker-compose.dev.yml
 *
 * Do NOT commit secrets to this file. Use environment variables.
 */

// ── Database (PostgreSQL) ──────────────────────────────────────────────────────
// Uses the PostgreSQL driver built into Drupal 11 core (pgsql module).

$databases['default']['default'] = [
  'database'  => getenv('DRUPAL_DB_NAME')     ?: 'drupal',
  'username'  => getenv('DRUPAL_DB_USER')     ?: 'drupal',
  'password'  => getenv('DRUPAL_DB_PASSWORD') ?: '',
  'host'      => getenv('DRUPAL_DB_HOST')     ?: 'postgres',
  'port'      => getenv('DRUPAL_DB_PORT')     ?: '5432',
  'driver'    => 'pgsql',
  'prefix'    => '',
  'namespace' => 'Drupal\\pgsql\\Driver\\Database\\pgsql',
  'autoload'  => 'core/modules/pgsql/src/Driver/Database/pgsql/',
];

// ── Hash salt ─────────────────────────────────────────────────────────────────
// Generate with: openssl rand -base64 55
// REQUIRED in production. Must be consistent across deploys.

$settings['hash_salt'] = getenv('DRUPAL_HASH_SALT') ?: 'docker-dev-salt-replace-in-env';

// ── Redis cache backend ───────────────────────────────────────────────────────
// Requires the redis module enabled in Drupal.

if (getenv('REDIS_HOST')) {
  $settings['redis.connection']['interface'] = 'PhpRedis';
  $settings['redis.connection']['host']      = getenv('REDIS_HOST');
  $settings['redis.connection']['port']      = (int) (getenv('REDIS_PORT') ?: 6379);
  if (getenv('REDIS_PASSWORD')) {
    $settings['redis.connection']['password'] = getenv('REDIS_PASSWORD');
  }
  $settings['cache']['default'] = 'cache.backend.redis';
  // Keep form cache in the database — forms are stateful and should not be evicted
  $settings['cache']['bins']['form'] = 'cache.backend.database';
}

// ── Config sync directory ─────────────────────────────────────────────────────
// Points to the config/sync directory in the webcms repo root.

$settings['config_sync_directory'] = '/opt/drupal/config/sync';

// ── File paths ────────────────────────────────────────────────────────────────

$settings['file_public_path']  = 'sites/default/files';
$settings['file_private_path'] = getenv('DRUPAL_PRIVATE_FILES') ?: '/opt/drupal/private';

// ── Trusted host patterns ─────────────────────────────────────────────────────
// Add any additional hostnames here or via DRUPAL_TRUSTED_HOST env var.

$settings['trusted_host_patterns'] = [
  '^localhost$',
  '^drupal$',
  '^drupal\.wilkesliberty\.com$',
  '^.*\.wilkesliberty\.com$',
];
if (getenv('DRUPAL_TRUSTED_HOST_PATTERN')) {
  $settings['trusted_host_patterns'][] = getenv('DRUPAL_TRUSTED_HOST_PATTERN');
}

// ── Environment-specific settings ────────────────────────────────────────────

$environment = getenv('DRUPAL_ENVIRONMENT') ?: 'production';

if ($environment === 'development') {
  // Show all errors in development
  error_reporting(E_ALL);
  ini_set('display_errors', TRUE);
  ini_set('display_startup_errors', TRUE);

  // Verbose Drupal logging
  $config['system.logging']['error_level'] = 'verbose';

  // Disable render/page caches so Twig templates and theme changes show immediately
  $settings['cache']['bins']['render']       = 'cache.backend.null';
  $settings['cache']['bins']['dynamic_page_cache'] = 'cache.backend.null';
  $settings['cache']['bins']['page']         = 'cache.backend.null';

  // Use development.services.yml for debugging helpers if present
  if (file_exists(DRUPAL_ROOT . '/sites/development.services.yml')) {
    $settings['container_yamls'][] = DRUPAL_ROOT . '/sites/development.services.yml';
  }
}

// ── Disable update checks ─────────────────────────────────────────────────────
// Updates are managed via Composer, not the UI.

$config['update.settings']['check'] = FALSE;

// ── Automated cron ────────────────────────────────────────────────────────────
// Disable automated cron — run via drush cron on a schedule instead.

$config['automated_cron.settings']['interval'] = 0;
