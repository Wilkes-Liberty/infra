<?php
/**
 * Sanitizes all custom email-type entity fields in the Drupal DB.
 *
 * Enumerated dynamically via field_storage_config so it handles any
 * custom email fields regardless of entity type or field name.
 * Safe to re-run: the UPDATE result is deterministic (entity_id is stable).
 *
 * Used by: ansible/playbooks/refresh-staging.yml (drush scr)
 */

$fields = \Drupal::entityTypeManager()
  ->getStorage('field_storage_config')
  ->loadByProperties(['type' => 'email']);

if (empty($fields)) {
  echo "No custom email fields found — skipping.\n";
  return;
}

$db = \Drupal::database();

foreach ($fields as $field) {
  $entity_type = $field->getTargetEntityTypeId();
  $field_name  = $field->getName();
  $col         = $field_name . '_value';

  $tables = [
    $entity_type . '__' . $field_name,
    $entity_type . '_revision__' . $field_name,
  ];

  foreach ($tables as $table) {
    if (!$db->schema()->tableExists($table)) {
      continue;
    }
    $db->query(
      "UPDATE {$table} SET {$col} = CONCAT('noreply+stg-', entity_id, '@wilkesliberty.com') WHERE {$col} IS NOT NULL AND {$col} != ''"
    );
    echo "Sanitized {$table}.{$col}\n";
  }
}
