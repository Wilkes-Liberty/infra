<?php
/**
 * Sanitizes email values in webform_submission_data and webform_submission.
 *
 * Enumerates email-type elements from all webform entities, then rewrites
 * matching rows in webform_submission_data (column: name, not element_id).
 * Also sanitizes remote_addr in webform_submission to '127.0.0.1'.
 * Safe to re-run: result is deterministic (sid is stable).
 *
 * Used by: ansible/playbooks/refresh-staging.yml (drush scr)
 */

if (!\Drupal::moduleHandler()->moduleExists('webform')) {
  echo "Webform module not installed — skipping.\n";
  return;
}

$db = \Drupal::database();

// Sanitize remote_addr (IP PII) in webform_submission.
if ($db->schema()->tableExists('webform_submission')) {
  $db->query("UPDATE {webform_submission} SET remote_addr = '127.0.0.1'");
  echo "Sanitized webform_submission.remote_addr → 127.0.0.1\n";
}

// Enumerate email-type element machine names across all webforms.
$email_elements = [];

/** @var \Drupal\webform\WebformInterface[] $webforms */
$webforms = \Drupal::entityTypeManager()->getStorage('webform')->loadMultiple();

foreach ($webforms as $webform) {
  try {
    $elements = $webform->getElementsDecoded();
  }
  catch (\Exception $e) {
    echo "Warning: could not decode elements for {$webform->id()}: {$e->getMessage()}\n";
    continue;
  }

  if (!is_array($elements)) {
    continue;
  }

  foreach ($elements as $key => $def) {
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
  echo "No webform email elements found — skipping submission data sanitization.\n";
  return;
}

if (!$db->schema()->tableExists('webform_submission_data')) {
  echo "webform_submission_data table not found — no submissions to sanitize.\n";
  return;
}

$args = [];
foreach ($email_elements as $i => $el) {
  $args[':elem_' . $i] = $el;
}

$db->query(
  "UPDATE {webform_submission_data} SET value = CONCAT('noreply+stg-webform-', sid, '@wilkesliberty.com') WHERE name IN (" . implode(', ', array_keys($args)) . ") AND value IS NOT NULL AND value != ''",
  $args
);

echo "Webform submission emails sanitized for elements: " . implode(', ', $email_elements) . "\n";
