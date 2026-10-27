<?php
/**
 * Appearance > Site setup: one button that builds the site from inc/content/pages.json.
 *
 * It adds the theme's game images to the Media Library (so WordPress makes its smaller sizes and srcset), creates
 * every page at its fixed address (/games/<game>/, /games/<game>/privacy/, ...), sets the home page, and turns on
 * /%postname%/ links if the site still has plain ones. It is safe to press again: it never makes a second copy, and
 * it only refreshes a page it made if nobody has edited that page since.
 *
 * Shared hosts often stop a request after 30 seconds, so the work is done in rounds of about 15 seconds; the page
 * carries on by itself until it is done.
 *
 * @package ghost-kit
 */

defined( 'ABSPATH' ) || exit;

const GHOSTKIT_SETUP_OPTION = 'ghostkit_setup';

/** The pages and images to create, from the theme. */
function ghostkit_content() {
	static $content = null;
	if ( null === $content ) {
		$content = json_decode( (string) file_get_contents( get_theme_file_path( 'inc/content/pages.json' ) ), true );
	}
	return $content;
}

/** The attachment made from a theme image, by its key (e.g. "hurling-heroes-icon"), or 0. */
function ghostkit_asset_id( $key ) {
	$ids = get_posts(
		array(
			'post_type'      => 'attachment',
			'post_status'    => 'inherit',
			'meta_key'       => '_ghostkit_asset',
			'meta_value'     => $key,
			'fields'         => 'ids',
			'posts_per_page' => 1,
		)
	);
	return $ids ? (int) $ids[0] : 0;
}

/** Adds one theme image to the Media Library. Returns the attachment ID, or a WP_Error. */
function ghostkit_import_asset( $asset ) {
	require_once ABSPATH . 'wp-admin/includes/file.php';
	require_once ABSPATH . 'wp-admin/includes/media.php';
	require_once ABSPATH . 'wp-admin/includes/image.php';

	$src = get_theme_file_path( 'assets/images/' . $asset['file'] );
	$tmp = wp_tempnam( basename( $src ) );
	if ( ! $tmp || ! copy( $src, $tmp ) ) {
		return new WP_Error( 'ghostkit_copy', 'Could not copy ' . $asset['file'] );
	}
	$id = media_handle_sideload(
		array(
			'name'     => basename( $src ),
			'tmp_name' => $tmp,
		),
		0,
		$asset['title']
	);
	if ( is_wp_error( $id ) ) {
		wp_delete_file( $tmp );
		return $id;
	}
	update_post_meta( $id, '_ghostkit_asset', $asset['key'] );
	update_post_meta( $id, '_wp_attachment_image_alt', $asset['alt'] );
	return $id;
}

/** Puts the real attachment IDs and URLs where the content has %%ID:key%% and %%URL:key:size%%. */
function ghostkit_fill_tokens( $content, $ids ) {
	$content = preg_replace_callback(
		'/%%ID:([a-z0-9-]+)%%/',
		function ( $m ) use ( $ids ) {
			return (string) ( $ids[ $m[1] ] ?? 0 );
		},
		$content
	);
	return preg_replace_callback(
		'/%%URL:([a-z0-9-]+):([a-z_]+)%%/',
		function ( $m ) use ( $ids ) {
			$id = $ids[ $m[1] ] ?? 0;
			if ( ! $id ) {
				return '';
			}
			$url = 'full' === $m[2] ? wp_get_attachment_url( $id ) : wp_get_attachment_image_url( $id, $m[2] );
			return (string) $url;
		},
		$content
	);
}

/**
 * Does as much of the setup as fits in about 15 seconds. Returns array( done => bool, log => string[] ).
 */
function ghostkit_run_setup() {
	if ( function_exists( 'set_time_limit' ) ) {
		@set_time_limit( 120 ); // phpcs:ignore WordPress.PHP.NoSilencedErrors -- some hosts forbid it; we stop early anyway.
	}
	$start   = microtime( true );
	$content = ghostkit_content();
	$log     = array();

	// 1. Images, one at a time, until the time is up.
	$ids = array();
	foreach ( $content['assets'] as $asset ) {
		$id = ghostkit_asset_id( $asset['key'] );
		if ( ! $id ) {
			if ( microtime( true ) - $start > 15 ) {
				$done = count( $ids );
				return array(
					'done' => false,
					'log'  => array( sprintf( 'Added %d of %d images to the Media Library…', $done, count( $content['assets'] ) ) ),
				);
			}
			$id = ghostkit_import_asset( $asset );
			if ( is_wp_error( $id ) ) {
				return array(
					'done'  => true,
					'error' => true,
					'log'   => array( 'Could not add ' . $asset['file'] . ' to the Media Library: ' . $id->get_error_message() ),
				);
			}
		}
		$ids[ $asset['key'] ] = $id;
	}
	$log[] = sprintf( 'Images: %d in the Media Library.', count( $ids ) );

	// 2. Pages, parents first (the content lists them in that order).
	$made    = 0;
	$updated = 0;
	$kept    = 0;
	foreach ( $content['pages'] as $page ) {
		$parts     = explode( '/', $page['path'] );
		$slug      = array_pop( $parts );
		$parent    = $parts ? get_page_by_path( implode( '/', $parts ) ) : null;
		$body      = ghostkit_fill_tokens( $page['content'], $ids );
		$existing  = get_page_by_path( $page['path'] );
		$postarr   = array(
			'post_type'    => 'page',
			'post_status'  => 'publish',
			'post_title'   => $page['title'],
			'post_name'    => $slug,
			'post_parent'  => $parent ? $parent->ID : 0,
			'post_content' => wp_slash( $body ),
			'post_excerpt' => wp_slash( $page['excerpt'] ),
			'menu_order'   => (int) $page['menu_order'],
			'comment_status' => 'closed',
			'ping_status'  => 'closed',
		);
		if ( ! $existing ) {
			$id = wp_insert_post( $postarr, true );
			if ( is_wp_error( $id ) ) {
				$log[] = 'Could not create ' . $page['path'] . ': ' . $id->get_error_message();
				continue;
			}
			++$made;
		} else {
			$id   = $existing->ID;
			$hash = get_post_meta( $id, '_ghostkit_hash', true );
			// Refresh only a page this setup made and nobody has changed since; leave everything else alone.
			if ( $hash && md5( $existing->post_content ) === $hash && md5( $body ) !== $hash ) {
				$postarr['ID'] = $id;
				unset( $postarr['post_status'], $postarr['post_name'], $postarr['post_parent'] );
				wp_update_post( $postarr );
				++$updated;
			} else {
				++$kept;
				continue;
			}
		}
		update_post_meta( $id, '_ghostkit_hash', md5( get_post_field( 'post_content', $id, 'raw' ) ) );
		update_post_meta( $id, '_ghostkit_path', $page['path'] );
		if ( $page['template'] ) {
			update_post_meta( $id, '_wp_page_template', $page['template'] );
		}
	}
	$log[] = sprintf( 'Pages: %d created, %d refreshed, %d left as they were.', $made, $updated, $kept );

	// 3. Home page, links, comments and the logo.
	$home = get_page_by_path( 'home' );
	if ( $home && 'page' !== get_option( 'show_on_front' ) ) {
		update_option( 'show_on_front', 'page' );
		update_option( 'page_on_front', $home->ID );
		$log[] = 'Home is now the front page.';
	}
	if ( '' === (string) get_option( 'permalink_structure' ) ) {
		update_option( 'permalink_structure', '/%postname%/' );
		$log[] = 'Permalinks set to /%postname%/.';
	}
	update_option( 'default_comment_status', 'closed' );
	update_option( 'default_ping_status', 'closed' );
	$tagline = (string) get_option( 'blogdescription' );
	if ( '' === $tagline || 'Just another WordPress site' === $tagline ) {
		update_option( 'blogdescription', 'Mobile sports games' );
	}
	if ( ! get_theme_mod( 'custom_logo' ) ) {
		$logo = ghostkit_asset_id( 'site-logo' );
		if ( ! $logo ) {
			$logo = ghostkit_import_asset(
				array(
					'key'   => 'site-logo',
					'file'  => 'logo.png',
					'alt'   => '',
					'title' => 'Site logo',
				)
			);
		}
		if ( ! is_wp_error( $logo ) ) {
			set_theme_mod( 'custom_logo', $logo );
			update_option( 'site_logo', $logo );
			if ( ! get_option( 'site_icon' ) ) {
				update_option( 'site_icon', $logo );
			}
			$log[] = 'Logo and site icon set (change them under Appearance > Editor or Settings > General).';
		}
	}
	// WordPress's own sample post and page, if nobody has touched them, go to the Trash (they can be restored).
	foreach ( array( array( 'sample-page', 'page' ), array( 'hello-world', 'post' ) ) as $sample ) {
		$s = get_page_by_path( $sample[0], OBJECT, $sample[1] );
		if ( $s && 'publish' === $s->post_status && $s->post_date === $s->post_modified ) {
			wp_trash_post( $s->ID );
			$log[] = sprintf( 'Moved WordPress\'s sample "%s" to the Trash.', $s->post_title );
		}
	}
	flush_rewrite_rules();
	update_option( GHOSTKIT_SETUP_OPTION, array( 'version' => GHOSTKIT_VERSION, 'time' => time() ) );
	return array(
		'done' => true,
		'log'  => $log,
	);
}

add_action(
	'admin_menu',
	function () {
		add_theme_page( 'Site setup', 'Site setup', 'manage_options', 'ghostkit-setup', 'ghostkit_setup_page' );
	}
);

add_action(
	'admin_post_ghostkit_setup',
	function () {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( 'Sorry, only an administrator can do this.' );
		}
		check_admin_referer( 'ghostkit_setup' );
		$result = ghostkit_run_setup();
		set_transient( 'ghostkit_setup_log', $result, 600 );
		$args = array( 'page' => 'ghostkit-setup' );
		if ( ! $result['done'] ) {
			$args['continue'] = 1;
		}
		wp_safe_redirect( add_query_arg( $args, admin_url( 'themes.php' ) ) );
		exit;
	}
);

/** The Site setup screen. */
function ghostkit_setup_page() {
	$result  = get_transient( 'ghostkit_setup_log' );
	$going   = ! empty( $_GET['continue'] ); // phpcs:ignore WordPress.Security.NonceVerification -- display only.
	$content = ghostkit_content();
	$action  = admin_url( 'admin-post.php' );
	echo '<div class="wrap"><h1>Site setup</h1>';
	if ( $result ) {
		$class = ! empty( $result['error'] ) ? 'notice-error' : ( $result['done'] ? 'notice-success' : 'notice-info' );
		echo '<div class="notice ' . esc_attr( $class ) . '"><p>' . implode( '<br>', array_map( 'esc_html', $result['log'] ) ) . '</p></div>';
		if ( $result['done'] ) {
			delete_transient( 'ghostkit_setup_log' );
		}
	}
	echo '<p>This makes every page of the site from the theme: the home page, the games, each game\'s privacy policy and help page, About, Press kit, Contact and support, Privacy and Licences. It also adds the game images to the Media Library and makes Home the front page.</p>';
	echo '<p>You can press it again at any time. It never makes a second copy of a page, and it never changes a page you have edited.</p>';
	echo '<form method="post" action="' . esc_url( $action ) . '" id="ghostkit-setup-form">';
	wp_nonce_field( 'ghostkit_setup' );
	echo '<input type="hidden" name="action" value="ghostkit_setup">';
	submit_button( $going ? 'Carrying on…' : 'Set up the site', 'primary', 'submit', false );
	echo '</form>';
	if ( $going ) {
		echo '<p>Still working: this page carries on by itself. Please leave it open.</p>';
		echo '<script>setTimeout(function(){document.getElementById("ghostkit-setup-form").submit();},500);</script>';
	}
	echo '<h2>Pages</h2><table class="widefat striped"><thead><tr><th>Address</th><th>Page</th></tr></thead><tbody>';
	foreach ( $content['pages'] as $page ) {
		$p   = get_page_by_path( $page['path'] );
		$url = 'home' === $page['path'] ? home_url( '/' ) : home_url( '/' . $page['path'] . '/' );
		echo '<tr><td><code>' . esc_html( wp_make_link_relative( $url ) ) . '</code></td><td>';
		echo $p ? '<a href="' . esc_url( get_permalink( $p ) ) . '">' . esc_html( get_the_title( $p ) ) . '</a>' : '<em>not made yet</em>';
		echo '</td></tr>';
	}
	echo '</tbody></table></div>';
}

// Until the setup has run, say so on the dashboard and the themes screen.
add_action(
	'admin_notices',
	function () {
		$screen = get_current_screen();
		if ( get_option( GHOSTKIT_SETUP_OPTION ) || ! current_user_can( 'manage_options' ) || ! $screen || ! in_array( $screen->id, array( 'dashboard', 'themes' ), true ) ) {
			return;
		}
		printf(
			'<div class="notice notice-info"><p><strong>One more step:</strong> make the site\'s pages. <a class="button button-primary" href="%s">Go to Site setup</a></p></div>',
			esc_url( admin_url( 'themes.php?page=ghostkit-setup' ) )
		);
	}
);
