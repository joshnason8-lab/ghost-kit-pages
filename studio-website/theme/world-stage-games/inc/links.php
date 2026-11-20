<?php
/**
 * Internal links that always work.
 *
 * The pages and menus link by path ("/games/kabaddi-raid/"). Written that way, a link breaks when WordPress still has
 * plain permalinks (?page_id=12), when the site lives in a sub-folder or on a temporary address, or before Settings >
 * Permalinks has been saved. So as each block is shown, every such path is swapped for the page's real address from
 * WordPress (get_permalink), or for the address under the site's home if it isn't a page. Nothing is stored; the pages
 * keep their short paths, so moving the site to another domain needs no edits.
 *
 * @package world-stage-games
 */

defined( 'ABSPATH' ) || exit;

/** The real address for a site path like "/games/kabaddi-raid/#beta". */
function ghostkit_resolve_path( $path ) {
	static $cache = array();
	if ( isset( $cache[ $path ] ) ) {
		return $cache[ $path ];
	}
	$asked    = $path;
	$fragment = '';
	if ( false !== ( $hash = strpos( $path, '#' ) ) ) {
		$fragment = substr( $path, $hash );
		$path     = substr( $path, 0, $hash );
	}
	$query = '';
	if ( false !== ( $q = strpos( $path, '?' ) ) ) {
		$query = substr( $path, $q );
		$path  = substr( $path, 0, $q );
	}
	$slug = trim( $path, '/' );
	if ( '' === $slug ) {
		$url = home_url( '/' );
	} else {
		$page = get_page_by_path( $slug );
		$url  = $page ? get_permalink( $page ) : home_url( '/' . $slug . '/' );
	}
	$cache[ $asked ] = $url . $query . $fragment;
	return $cache[ $asked ];
}

/** Swaps every href="/…" (not "//…", which is another site) in a piece of HTML for its real address. */
function ghostkit_resolve_links( $html ) {
	if ( ! str_contains( $html, 'href="/' ) ) {
		return $html;
	}
	return preg_replace_callback(
		'#\bhref="(/(?!/)[^"]*)"#',
		function ( $m ) {
			return 'href="' . esc_url( ghostkit_resolve_path( html_entity_decode( $m[1] ) ) ) . '"';
		},
		$html
	);
}

// Every block on the front end: the pages' content, the header and footer menus, the buttons.
add_filter(
	'render_block',
	function ( $html ) {
		return is_admin() ? $html : ghostkit_resolve_links( $html );
	},
	20
);

// Make sure the links have pretty addresses to begin with: on activation, if the site still has plain permalinks,
// switch to /%postname%/ (the same as Settings > Permalinks > Post name) and write the rewrite rules.
add_action(
	'after_switch_theme',
	function () {
		if ( '' === (string) get_option( 'permalink_structure' ) ) {
			global $wp_rewrite;
			$wp_rewrite->set_permalink_structure( '/%postname%/' );
			flush_rewrite_rules( true );
		}
	}
);
