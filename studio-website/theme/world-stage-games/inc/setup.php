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
 * @package world-stage-games
 */

defined( 'ABSPATH' ) || exit;

const GHOSTKIT_SETUP_OPTION  = 'ghostkit_setup';
const GHOSTKIT_STUDIO_NAME    = 'World Stage Games';
const GHOSTKIT_STUDIO_TAGLINE = 'Every game deserves a stage.';

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
	if ( ! empty( $asset['caption'] ) ) {
		// The credit line, so it travels with the photo in the Media Library.
		wp_update_post( array( 'ID' => $id, 'post_excerpt' => $asset['caption'] ) );
	}
	return $id;
}

/** A theme image in the Media Library (added the first time): its attachment ID, or 0 if it couldn't be added. */
function ghostkit_ensure_asset( $key, $file, $title ) {
	$id = ghostkit_asset_id( $key );
	if ( ! $id ) {
		$id = ghostkit_import_asset(
			array(
				'key'   => $key,
				'file'  => $file,
				'alt'   => get_bloginfo( 'name' ),
				'title' => $title,
			)
		);
	}
	return is_wp_error( $id ) ? 0 : (int) $id;
}

/**
 * Asks the site for its own Games page, the way a visitor would, and says whether the links work. Some hosts don't
 * let a site call itself; then it says so instead of guessing.
 */
function ghostkit_check_links() {
	$page = get_page_by_path( 'games' );
	if ( ! $page ) {
		return 'Link check skipped: the Games page isn\'t there yet.';
	}
	$url      = get_permalink( $page );
	$response = wp_remote_get( $url, array( 'timeout' => 8, 'redirection' => 3, 'sslverify' => false ) );
	if ( is_wp_error( $response ) ) {
		return 'Link check: this server can\'t open its own pages to test them (' . $response->get_error_message() . '). Open the site and click a game to check.';
	}
	$code = (int) wp_remote_retrieve_response_code( $response );
	if ( 200 === $code ) {
		return 'Link check: ' . wp_make_link_relative( $url ) . ' opens (200). The links work.';
	}
	return 'Link check: ' . wp_make_link_relative( $url ) . ' answered ' . $code . '. Go to Settings > Permalinks and press Save Changes; if pages still say "not found", ask Bluehost to make the site\'s .htaccess file writable.';
}

/** Downloads a game's web trailer and adds it to the Media Library as <game>-trailer.mp4. */
function ghostkit_fetch_trailer( $game, $url ) {
	require_once ABSPATH . 'wp-admin/includes/file.php';
	require_once ABSPATH . 'wp-admin/includes/media.php';
	require_once ABSPATH . 'wp-admin/includes/image.php';
	$tmp = download_url( $url, 120 );
	if ( is_wp_error( $tmp ) ) {
		return $tmp;
	}
	$id = media_handle_sideload(
		array(
			'name'     => $game . '-trailer.mp4',
			'tmp_name' => $tmp,
		),
		0,
		$game . '-trailer'
	);
	if ( is_wp_error( $id ) ) {
		wp_delete_file( $tmp );
	}
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
 * The game's trailer, if a video named <game>-trailer….mp4 is in the Media Library: its attachment ID, or 0.
 */
function ghostkit_trailer_id( $game, $refresh = false ) {
	static $videos = null;
	if ( null === $videos || $refresh ) {
		$videos = array();
		$ids    = get_posts(
			array(
				'post_type'      => 'attachment',
				'post_status'    => 'inherit',
				'post_mime_type' => 'video',
				'posts_per_page' => -1,
				'fields'         => 'ids',
				'orderby'        => 'date',
				'order'          => 'DESC',
			)
		);
		foreach ( $ids as $id ) {
			// The file name, or the title WordPress gave it (the file name without ".mp4"), in lower case.
			$videos[ $id ] = strtolower( basename( (string) get_attached_file( $id ) ) . ' ' . get_the_title( $id ) );
		}
	}
	// "hurling-heroes-trailer.mp4", and also "hurling-heroes-trailer-1.mp4" or "Hurling Heroes trailer" after a
	// rename, but not a vertical or social cut.
	$name = implode( '[- _]', array_map( 'preg_quote', explode( '-', $game ) ) );
	foreach ( $videos as $id => $label ) {
		if ( preg_match( '/' . $name . '[- _]trailer/', $label ) && ! preg_match( '/vertical|social|1080x1920/', $label ) ) {
			return (int) $id;
		}
	}
	return 0;
}

/**
 * On a game page, the trailer slot: a video player when the trailer is in the Media Library, otherwise the title art
 * with "Trailer coming soon". The markers around the slot are removed either way.
 */
function ghostkit_fill_trailers( $content, $ids ) {
	return preg_replace_callback(
		'#<!--gk-trailer:([a-z0-9-]+)-->(.*?)<!--/gk-trailer-->#s',
		function ( $m ) use ( $ids ) {
			$video = ghostkit_trailer_id( $m[1] );
			if ( ! $video ) {
				return $m[2];
			}
			$poster = isset( $ids[ $m[1] . '-feature' ] ) ? wp_get_attachment_image_url( $ids[ $m[1] . '-feature' ], 'large' ) : '';
			return sprintf(
				"<!-- wp:group {\"className\":\"gk-trailer\"} -->\n<div class=\"wp-block-group gk-trailer\"><!-- wp:video {\"id\":%1\$d} -->\n" .
				"<figure class=\"wp-block-video\"><video controls poster=\"%2\$s\" preload=\"none\" src=\"%3\$s\"></video></figure>\n" .
				"<!-- /wp:video --></div>\n<!-- /wp:group -->",
				$video,
				esc_url( $poster ),
				esc_url( wp_get_attachment_url( $video ) )
			);
		},
		$content
	);
}

/**
 * Does as much of the setup as fits in about 15 seconds (the ghostkit_setup_seconds filter). Returns array( done => bool, log => string[] ).
 */
function ghostkit_run_setup() {
	if ( function_exists( 'set_time_limit' ) ) {
		@set_time_limit( 120 ); // phpcs:ignore WordPress.PHP.NoSilencedErrors -- some hosts forbid it; we stop early anyway.
	}
	$start   = microtime( true );
	/** Seconds of work per round. Lower it if a host stops requests sooner than 30 seconds. */
	$budget  = (float) apply_filters( 'ghostkit_setup_seconds', 15 );
	$content = ghostkit_content();
	$log     = array();

	// 1. Images, one at a time, until the time is up.
	$ids = array();
	foreach ( $content['assets'] as $asset ) {
		$id = ghostkit_asset_id( $asset['key'] );
		if ( ! $id ) {
			if ( microtime( true ) - $start > $budget ) {
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

	// 1b. The trailers, fetched from GitHub straight into the Media Library (no upload from your computer), one at a
	// time until the time is up. A game page shows its trailer as soon as it is in.
	$have = 0;
	foreach ( (array) ( $content['trailers'] ?? array() ) as $game => $url ) {
		if ( ghostkit_trailer_id( $game, true ) ) {
			++$have;
			continue;
		}
		if ( microtime( true ) - $start > $budget ) {
			return array(
				'done' => false,
				'log'  => array( sprintf( 'Adding the trailers to the Media Library: %d of %d…', $have, count( $content['trailers'] ) ) ),
			);
		}
		$added = ghostkit_fetch_trailer( $game, $url );
		if ( is_wp_error( $added ) ) {
			$log[] = sprintf( 'Could not fetch the %s trailer (%s). You can upload it yourself under Media > Add New Media File.', $game, $added->get_error_message() );
		} else {
			++$have;
		}
	}
	if ( ! empty( $content['trailers'] ) ) {
		$log[] = sprintf( 'Trailers: %d of %d in the Media Library.', $have, count( $content['trailers'] ) );
	}

	// 2. Pages, parents first (the content lists them in that order).
	$made    = 0;
	$updated = 0;
	$kept    = 0;
	foreach ( $content['pages'] as $page ) {
		$parts     = explode( '/', $page['path'] );
		$slug      = array_pop( $parts );
		$parent    = $parts ? get_page_by_path( implode( '/', $parts ) ) : null;
		$body      = ghostkit_fill_trailers( ghostkit_fill_tokens( $page['content'], $ids ), $ids );
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
		// The featured image is used for link previews (Open Graph); the page itself shows the photo in its text.
		if ( ! empty( $page['featured'] ) && ! empty( $ids[ $page['featured'] ] ) ) {
			set_post_thumbnail( $id, $ids[ $page['featured'] ] );
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
	// The studio's name and tagline, unless the site already has its own.
	$name = (string) get_option( 'blogname' );
	if ( in_array( $name, array( '', 'Ghost Kit Games', 'My WordPress Website', 'My WordPress Site', 'My Blog', 'WordPress' ), true ) ) {
		update_option( 'blogname', GHOSTKIT_STUDIO_NAME );
		$log[] = 'Site Title set to "' . GHOSTKIT_STUDIO_NAME . '" (change it under Settings > General).';
	}
	$tagline = (string) get_option( 'blogdescription' );
	if ( in_array( $tagline, array( '', 'Just another WordPress site', 'Mobile sports games' ), true ) ) {
		update_option( 'blogdescription', GHOSTKIT_STUDIO_TAGLINE );
	}
	// The logo (the wordmark in the header) and the site icon (the browser tab), unless the site already has its own.
	// The placeholder ghost logo from the first version of this theme counts as "not its own".
	$old_ghost = ghostkit_asset_id( 'site-logo' );
	$logo      = ghostkit_ensure_asset( 'site-logo-wordmark', 'logo.png', 'Site logo' );
	$icon      = ghostkit_ensure_asset( 'site-icon-ticket', 'icon.png', 'Site icon' );
	$current   = (int) get_theme_mod( 'custom_logo' ) ?: (int) get_option( 'site_logo' );
	if ( $logo && ( ! $current || $current === $old_ghost ) ) {
		set_theme_mod( 'custom_logo', $logo );
		update_option( 'site_logo', $logo );
		$log[] = 'Logo set (change it under Appearance > Editor, by clicking the logo in the header).';
	}
	$current_icon = (int) get_option( 'site_icon' );
	if ( $icon && ( ! $current_icon || $current_icon === $old_ghost ) ) {
		update_option( 'site_icon', $icon );
		$log[] = 'Site icon set (change it under Settings > General > Site Icon).';
	}
	// WordPress's own sample post and page, if nobody has touched them, go to the Trash (they can be restored).
	foreach ( array( array( 'sample-page', 'page' ), array( 'hello-world', 'post' ) ) as $sample ) {
		$s = get_page_by_path( $sample[0], OBJECT, $sample[1] );
		if ( $s && 'publish' === $s->post_status && $s->post_date === $s->post_modified ) {
			wp_trash_post( $s->ID );
			$log[] = sprintf( 'Moved WordPress\'s sample "%s" to the Trash.', $s->post_title );
		}
	}
	require_once ABSPATH . 'wp-admin/includes/misc.php';
	flush_rewrite_rules( true ); // also writes .htaccess where the server allows it
	$log[] = ghostkit_check_links();
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

/** The theme's version of a page's content, with this site's image IDs and trailers filled in. */
function ghostkit_theme_body( $page ) {
	static $ids = null;
	if ( null === $ids ) {
		$ids = array();
		foreach ( ghostkit_content()['assets'] as $asset ) {
			$ids[ $asset['key'] ] = ghostkit_asset_id( $asset['key'] );
		}
	}
	return ghostkit_fill_trailers( ghostkit_fill_tokens( $page['content'], $ids ), $ids );
}

/** Puts the theme's version back into an existing page (WordPress keeps the old content as a revision). */
function ghostkit_reset_page( $page ) {
	$existing = get_page_by_path( $page['path'] );
	if ( ! $existing ) {
		return false;
	}
	wp_update_post(
		array(
			'ID'           => $existing->ID,
			'post_content' => wp_slash( ghostkit_theme_body( $page ) ),
			'post_excerpt' => wp_slash( $page['excerpt'] ),
		)
	);
	update_post_meta( $existing->ID, '_ghostkit_hash', md5( get_post_field( 'post_content', $existing->ID, 'raw' ) ) );
	update_post_meta( $existing->ID, '_ghostkit_path', $page['path'] );
	if ( $page['template'] ) {
		update_post_meta( $existing->ID, '_wp_page_template', $page['template'] );
	}
	return true;
}

// "Reset to the theme's version": one page (path=…) or every page that differs (path=*).
add_action(
	'admin_post_ghostkit_reset',
	function () {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( 'Sorry, only an administrator can do this.' );
		}
		check_admin_referer( 'ghostkit_reset' );
		$want = isset( $_POST['path'] ) ? sanitize_text_field( wp_unslash( $_POST['path'] ) ) : '';
		$done = array();
		foreach ( ghostkit_content()['pages'] as $page ) {
			if ( '*' !== $want && $page['path'] !== $want ) {
				continue;
			}
			$existing = get_page_by_path( $page['path'] );
			if ( $existing && md5( $existing->post_content ) !== md5( ghostkit_theme_body( $page ) ) && ghostkit_reset_page( $page ) ) {
				$done[] = $page['title'];
			}
		}
		$log = $done ? array( 'Reset to the theme\'s version: ' . implode( ', ', $done ) . '. (The old content is kept as a revision of each page.)' ) : array( 'Nothing needed resetting.' );
		set_transient( 'ghostkit_setup_log', array( 'done' => true, 'log' => $log ), 600 );
		wp_safe_redirect( add_query_arg( 'page', 'ghostkit-setup', admin_url( 'themes.php' ) ) );
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
	submit_button( $going ? 'Carrying on…' : 'Set up the site', 'primary', 'ghostkit_go', false );
	echo '</form>';
	if ( $going ) {
		echo '<p>Still working: this page carries on by itself. Please leave it open.</p>';
		echo '<script>setTimeout(function(){HTMLFormElement.prototype.submit.call(document.getElementById("ghostkit-setup-form"));},500);</script>';
	}
	$confirm = 'This replaces the page with the theme\'s version. Any changes you made to it are replaced too; WordPress keeps the old version under the page\'s Revisions. Carry on?';
	$reset   = function ( $path, $label, $class ) use ( $action, $confirm ) {
		$form  = '<form method="post" action="' . esc_url( $action ) . '" style="display:inline" onsubmit="return confirm(' . esc_attr( wp_json_encode( $confirm ) ) . ')">';
		$form .= wp_nonce_field( 'ghostkit_reset', '_wpnonce', true, false );
		$form .= '<input type="hidden" name="action" value="ghostkit_reset"><input type="hidden" name="path" value="' . esc_attr( $path ) . '">';
		return $form . '<button type="submit" class="button ' . esc_attr( $class ) . '">' . esc_html( $label ) . '</button></form>';
	};
	$rows    = '';
	$differs = 0;
	foreach ( $content['pages'] as $page ) {
		$p   = get_page_by_path( $page['path'] );
		$url = 'home' === $page['path'] ? home_url( '/' ) : home_url( '/' . $page['path'] . '/' );
		$rows .= '<tr><td><code>' . esc_html( wp_make_link_relative( $url ) ) . '</code></td><td>';
		$rows .= $p ? '<a href="' . esc_url( get_permalink( $p ) ) . '">' . esc_html( get_the_title( $p ) ) . '</a>' : '<em>not made yet</em>';
		$rows .= '</td><td>';
		if ( $p && md5( $p->post_content ) !== md5( ghostkit_theme_body( $page ) ) ) {
			++$differs;
			$rows .= 'Differs from the theme\'s version (edited, imported or from an older version) ' . $reset( $page['path'], 'Reset to the theme\'s version', 'button-small' );
		} elseif ( $p ) {
			$rows .= 'Up to date';
		}
		$rows .= '</td></tr>';
	}
	echo '<h2>Pages</h2>';
	if ( $differs ) {
		echo '<div class="notice notice-warning inline"><p>' . esc_html( sprintf( '%d of the pages differ from the theme\'s version. Set up the site never changes those, in case you edited them. To bring one up to date, reset it; to bring them all, ', $differs ) ) . '</p><p>' . $reset( '*', 'Reset every page that differs', 'button-secondary' ) . '</p></div>'; // phpcs:ignore WordPress.Security.EscapeOutput -- built from escaped parts.
	}
	echo '<table class="widefat striped"><thead><tr><th>Address</th><th>Page</th><th>Status</th></tr></thead><tbody>' . $rows . '</tbody></table></div>'; // phpcs:ignore WordPress.Security.EscapeOutput -- built from escaped parts.
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
