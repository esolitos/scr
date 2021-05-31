<?php

/*
 * # To Configure:
 *
 * - TPL_site_domain  ==> Domain Name for the site
 * - TPL_hash_salt    ==> Password salt: openssl rand -hex 32
 *
 * - TPL_db_name      => Database name
 * - TPL_db_user      => Database access username
 * - TPL_db_pass      => Database access password
 */

$eso_domain = 'TPL_site_domain';
$eso_proto = 'http';

if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') {
  $_SERVER['HTTPS'] = 'on';
  $eso_proto = 'https';
}

if (isset($_SERVER['HTTP_X_REAL_IP'])) {
  $_SERVER['REMOTE_ADDR'] = $_SERVER['HTTP_X_REAL_IP'];
}

$base_url = "${eso_proto}://{$eso_domain}";
$update_free_access = FALSE;
$drupal_hash_salt = 'TPL_hash_salt';

$databases['default']['default'] =[
  'host' => 'localhost',
  'database' => 'TPL_db_name',
  'username' => 'TPL_db_user',
  'password' => 'TPL_db_pass',
  'driver' => 'mysql',
];

$conf['file_public_path'] = "sites/default/files";
$conf['file_private_path'] = "/var/www/files/{$eso_domain}/private";
$conf['file_temporary_path'] = '/tmp';
