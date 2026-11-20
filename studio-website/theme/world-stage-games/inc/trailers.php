<?php
/**
 * Game trailers, as soon as they are in the Media Library.
 *
 * A game page has a trailer slot (the title art with "Trailer coming soon"). When a video named after the game
 * (hurling-heroes-trailer.mp4) is in the Media Library, the slot shows that video instead, on the page as it is now,
 * edited or not, with no button to press. Nothing loads until the visitor presses play; the title art is its cover.
 * Delete the video from the Media Library and the slot goes back to the title art.
 *
 * @package world-stage-games
 */

defined( 'ABSPATH' ) || exit;

add_filter(
	'render_block_core/group',
	function ( $html, $block ) {
		if ( ! str_contains( (string) ( $block['attrs']['className'] ?? '' ), 'gk-trailer' ) || str_contains( $html, '<video' ) ) {
			return $html;
		}
		$game = is_singular( 'page' ) ? ghostkit_page_game( get_queried_object() ) : '';
		$id   = $game ? ghostkit_trailer_id( $game ) : 0;
		if ( ! $id ) {
			return $html;
		}
		$art    = ghostkit_asset_id( $game . '-feature' );
		$poster = $art ? wp_get_attachment_image_url( $art, 'large' ) : '';
		return sprintf(
			'<div class="wp-block-group gk-trailer"><figure class="wp-block-video"><video controls playsinline preload="none"%s src="%s" title="%s"></video></figure></div>',
			$poster ? ' poster="' . esc_url( $poster ) . '"' : '',
			esc_url( wp_get_attachment_url( $id ) ),
			esc_attr( get_the_title( get_queried_object() ) . ' trailer' )
		);
	},
	10,
	2
);
