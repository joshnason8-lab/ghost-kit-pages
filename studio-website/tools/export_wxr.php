<?php
/**
 * Writes the site's pages and images as a WordPress export (WXR) to the file named in $GLOBALS['ghostkit_wxr_out'].
 * Run inside a WordPress where the theme's Site setup has run; tools/fix_wxr.py then makes it portable.
 */
require_once ABSPATH . 'wp-admin/includes/export.php';
ob_start();
export_wp( array( 'content' => 'all' ) );
file_put_contents( $GLOBALS['ghostkit_wxr_out'], ob_get_clean() );
