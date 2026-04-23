<?php
/**
 * Sanitizes email values in webform_submission_data.
 *
 * Enumerates email-type elements from all webform configs, then rewrites
 * matching rows in webform_submission_data.
 * Safe to re-run: result is deterministic (sid is stable).
 *
 * Used by: ansible/playbooks/refresh-staging.yml (drush scr)
 */

if (!\Drupal::moduleHandler()->moduleExists('webform')) {
  echo "Webform module not installed — skipping.\n";
  return;
}

$email_elements = [];

foreach (\Drupal::configFactory()->listAll('webform.webform.') as $name) {
  $raw = \Drupal::configFactory()->get($name)->get('elements');
  if (!is_string($raw) || empty($raw)) {
    continue;
  }

  try {
    $parsed = \Drupal::service('serialization.yaml')->decode($raw);
  }
  catch (\Exception $e) {
    echo "Warning: could not parse {$name}: {$e->getMessage()}\n";
    continue;
  }

  if (!is_array($parsed)) {
    continue;
  }

  foreach ($parsed as $key => $def) {
    if (
      is_array($def) &&
      isset($def['#type']) &&
      in_array($def['#type'], ['email', 'webform_email_confirm'], TRUE)
    ) {
      $email_elements[] = $key;
    }
  }
}

$email_elements = array_unique($email_elements);

if (empty($email_elements)) {
  echo "No webform email elements found — skipping.\n";
  return;
}

$db = \Drupal::database();

if (!$db->schema()->tableExists('webform_submission_data')) {
  echo "webform_submission_data table not found — no submissions to sanitize.\n";
  return;
}

$placeholders = implode(', ', array_fill(0, count($email_elements), ':elem_' . implode(', :elem_', range(0, count($email_elements) - 1))));

// Build a named-placeholder query for the IN clause.
$args = [];
foreach ($email_elements as $i => $el) {
  $args[':elem_' . $i] = $el;
}

$db->query(
  "UPDATE {webform_submission_data} SET value = CONCAT('noreply+stg-webform-', sid, '@wilkesliberty.com') WHERE element_id IN (" . implode(', ', array_keys($args)) . ") AND value IS NOT NULL AND value != ''",
  $args
);

echo "Webform submission emails sanitized for elements: " . implode(', ', $email_elements) . "\n";
