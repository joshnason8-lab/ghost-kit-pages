<?php
/**
 * The basics for search engines and link previews: a meta description and Open Graph / Twitter card tags.
 *
 * The description is the page's excerpt (set by Site setup; edit it in the page's sidebar, under Excerpt). The preview
 * image is the page's featured image if it has one, otherwise the game's title art for a game's pages, otherwise the
 * studio image. If an SEO plugin is active, this steps aside so the tags aren't doubled.
 *
 * @package ghost-kit
 */

defined( 'ABSPATH' ) || exit;

/** True when an SEO plugin that writes its own tags is active. */
function ghostkit_seo_plugin_active() {
	return defined( 'WPSEO_VERSION' ) || defined( 'RANK_MATH_VERSION' ) || defined( 'AIOSEO_VERSION' )
		|| defined( 'SEOPRESS_VERSION' ) || class_exists( 'The_SEO_Framework\Load' );
}

/** The game a page belongs to (its slug), from its address /games/<game>/..., or ''. */
function ghostkit_page_game( $post ) {
	$path = get_page_uri( $post );
	return preg_match( '#^games/([a-z0-9-]+)#', (string) $path, $m ) ? $m[1] : '';
}

/** The description for the current view. */
function ghostkit_meta_description() {
	if ( is_singular() ) {
		$post = get_queried_object();
		$text = has_excerpt( $post ) ? $post->post_excerpt : wp_trim_words( wp_strip_all_tags( strip_shortcodes( $post->post_content ) ), 28, '…' );
	} else {
		$text = get_bloginfo( 'description' );
	}
	return trim( preg_replace( '/\s+/', ' ', (string) $text ) );
}

/** The preview image URL for the current view. */
function ghostkit_og_image() {
	if ( is_singular() ) {
		$post = get_queried_object();
		if ( has_post_thumbnail( $post ) ) {
			return (string) get_the_post_thumbnail_url( $post, 'large' );
		}
		$game = ghostkit_page_game( $post );
		if ( $game && file_exists( get_theme_file_path( "assets/images/og/$game.jpg" ) ) ) {
			return get_theme_file_uri( "assets/images/og/$game.jpg" );
		}
	}
	return get_theme_file_uri( 'assets/images/og/default.jpg' );
}

add_action(
	'wp_head',
	function () {
		if ( ghostkit_seo_plugin_active() || is_404() ) {
			return;
		}
		$site  = get_bloginfo( 'name' );
		$title = is_front_page() ? $site : wp_get_document_title();
		$desc  = ghostkit_meta_description();
		$url   = is_singular() ? get_permalink() : home_url( add_query_arg( array() ) );
		$tags  = array(
			array( 'name', 'description', $desc ),
			array( 'property', 'og:type', is_front_page() ? 'website' : 'article' ),
			array( 'property', 'og:site_name', $site ),
			array( 'property', 'og:title', $title ),
			array( 'property', 'og:description', $desc ),
			array( 'property', 'og:url', $url ),
			array( 'property', 'og:image', ghostkit_og_image() ),
			array( 'property', 'og:locale', str_replace( '-', '_', get_bloginfo( 'language' ) ) ),
			array( 'name', 'twitter:card', 'summary_large_image' ),
		);
		foreach ( $tags as $t ) {
			if ( '' !== (string) $t[2] ) {
				printf( '<meta %s="%s" content="%s">' . "\n", $t[0], esc_attr( $t[1] ), esc_attr( $t[2] ) ); // phpcs:ignore WordPress.Security.EscapeOutput -- $t[0] is a fixed word.
			}
		}
	},
	5
);

// The home page's title is the site's name and tagline ("Ghost Kit Games – Mobile sports games"), WordPress's default.
// Every other page is "Page – Site", also the default. Nothing to change there.
