<?php
/**
 * Ghost Kit: a block theme for a studio of mobile sports games.
 *
 * The studio's name is the Site Title (Settings > General); nothing else in the theme names it. The pages come from
 * inc/content/pages.json through Appearance > Site setup (inc/setup.php). No plugins are needed.
 *
 * @package ghost-kit
 */

defined( 'ABSPATH' ) || exit;

define( 'GHOSTKIT_VERSION', wp_get_theme( get_template() )->get( 'Version' ) );

require get_template_directory() . '/inc/setup.php';
require get_template_directory() . '/inc/seo.php';

add_action(
	'after_setup_theme',
	function () {
		add_theme_support( 'wp-block-styles' );
		add_theme_support( 'editor-styles' );
		add_theme_support( 'responsive-embeds' );
		add_theme_support( 'custom-logo', array( 'height' => 68, 'width' => 68, 'flex-width' => true ) );
		add_editor_style( 'assets/css/site.css' );
		add_post_type_support( 'page', 'excerpt' );
	}
);

// One small stylesheet for the parts theme.json can't express. Loaded on every page; about 9 KB.
add_action(
	'wp_enqueue_scripts',
	function () {
		wp_enqueue_style( 'ghostkit', get_theme_file_uri( 'assets/css/site.css' ), array(), GHOSTKIT_VERSION );
		if ( ghostkit_has_filter() ) {
			wp_enqueue_script(
				'ghostkit-filter',
				get_theme_file_uri( 'assets/js/filter.js' ),
				array(),
				GHOSTKIT_VERSION,
				array( 'strategy' => 'defer', 'in_footer' => true )
			);
		}
	}
);

/** True on a page whose content has the game-card region filter. */
function ghostkit_has_filter() {
	return is_singular() && str_contains( (string) get_post_field( 'post_content' ), 'gk-filter' );
}

// Preload the two Latin font files every page uses, so headings don't flash in a fallback font.
add_action(
	'wp_head',
	function () {
		foreach ( array( 'oswald-latin-wght-normal.woff2', 'inter-latin-wght-normal.woff2' ) as $font ) {
			printf(
				'<link rel="preload" href="%s" as="font" type="font/woff2" crossorigin>' . "\n",
				esc_url( get_theme_file_uri( 'assets/fonts/' . $font ) )
			);
		}
	},
	1
);

// Lighter pages: no emoji script or styles (the browser draws emoji itself).
remove_action( 'wp_head', 'print_emoji_detection_script', 7 );
remove_action( 'wp_print_styles', 'print_emoji_styles' );
remove_action( 'admin_print_scripts', 'print_emoji_detection_script' );
remove_action( 'admin_print_styles', 'print_emoji_styles' );

// The site has no comments: close them everywhere and hide the comment feed links.
add_filter( 'comments_open', '__return_false', 20 );
add_filter( 'pings_open', '__return_false', 20 );
add_filter( 'feed_links_show_comments_feed', '__return_false' );

/**
 * [ghostkit_copyright]: "© 2026 Site Title", for the footer. The year is this year.
 */
add_shortcode(
	'ghostkit_copyright',
	function () {
		return sprintf(
			'<p class="gk-copyright">© %s %s</p>',
			esc_html( wp_date( 'Y' ) ),
			esc_html( get_bloginfo( 'name' ) )
		);
	}
);

/**
 * [ghostkit_breadcrumbs]: "Games › Hurling Heroes › Privacy", from the page's parents. Nothing on top-level pages.
 */
add_shortcode(
	'ghostkit_breadcrumbs',
	function () {
		if ( ! is_page() || is_front_page() ) {
			return '';
		}
		$post      = get_queried_object();
		$ancestors = array_reverse( get_post_ancestors( $post ) );
		if ( ! $ancestors ) {
			return '';
		}
		$items = array();
		foreach ( $ancestors as $id ) {
			$items[] = sprintf( '<li><a href="%s">%s</a></li>', esc_url( get_permalink( $id ) ), esc_html( get_the_title( $id ) ) );
		}
		$items[] = sprintf( '<li aria-current="page">%s</li>', esc_html( ghostkit_short_title( $post ) ) );
		return '<nav class="gk-crumb" aria-label="' . esc_attr__( 'Breadcrumb', 'ghost-kit' ) . '"><ol>' . implode( '', $items ) . '</ol></nav>';
	}
);

/** "Hurling Heroes privacy policy" reads as "Privacy policy" after "Hurling Heroes" in the breadcrumb. */
function ghostkit_short_title( $post ) {
	$title  = get_the_title( $post );
	$parent = $post->post_parent ? get_the_title( $post->post_parent ) : '';
	if ( $parent && str_starts_with( $title, $parent . ' ' ) ) {
		$title = ucfirst( substr( $title, strlen( $parent ) + 1 ) );
	}
	return $title;
}

/**
 * Pages brought in with Tools > Import keep their old image IDs, so WordPress can't add the smaller sizes (srcset)
 * to those images. Find the image by its file instead and add them. Costs nothing when the IDs already match.
 */
add_filter(
	'wp_content_img_tag',
	function ( $tag, $context, $attachment_id ) {
		if ( str_contains( $tag, ' srcset=' ) || ! preg_match( '/ src="([^"]+)"/', $tag, $m ) ) {
			return $tag;
		}
		$id = attachment_url_to_postid( preg_replace( '/-\d+x\d+(\.\w+)$/', '$1', $m[1] ) );
		if ( ! $id || $id === (int) $attachment_id ) {
			return $tag;
		}
		$meta = wp_get_attachment_metadata( $id );
		return is_array( $meta ) ? wp_image_add_srcset_and_sizes( $tag, $meta, $id ) : $tag;
	},
	10,
	3
);
