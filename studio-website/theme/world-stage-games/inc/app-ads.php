<?php
/**
 * Serves /app-ads.txt, the file AdMob reads to confirm which ad accounts may sell ads in the studio's apps
 * (Sepak Takraw Unleashed uses AdMob). WordPress answers it once permalinks are on; a real app-ads.txt file uploaded
 * to the site's root folder takes precedence, as the web server serves real files before WordPress.
 *
 * @package WorldStageGames
 */

defined( 'ABSPATH' ) || exit;

const GHOSTKIT_APP_ADS = "google.com, pub-1227543833347256, DIRECT, f08c47fec0942fa0\n";

add_action(
	'init',
	function () {
		$path = (string) wp_parse_url( isset( $_SERVER['REQUEST_URI'] ) ? wp_unslash( $_SERVER['REQUEST_URI'] ) : '', PHP_URL_PATH ); // phpcs:ignore WordPress.Security.ValidatedSanitizedInput
		$home = rtrim( (string) wp_parse_url( home_url( '/' ), PHP_URL_PATH ), '/' );
		if ( $path !== $home . '/app-ads.txt' ) {
			return;
		}
		status_header( 200 );
		header( 'Content-Type: text/plain; charset=utf-8' );
		header( 'X-Robots-Tag: noindex' );
		header( 'Cache-Control: public, max-age=3600' );
		echo GHOSTKIT_APP_ADS; // phpcs:ignore WordPress.Security.EscapeOutput
		exit;
	},
	0
);
