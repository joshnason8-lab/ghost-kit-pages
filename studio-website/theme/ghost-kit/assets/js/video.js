/**
 * Videos on the sport pages: nothing loads from YouTube until the visitor presses play. Then the button becomes the
 * video, from YouTube's privacy-enhanced domain. Without this script, the "Watch on YouTube" link under it still works.
 */
( function () {
	document.querySelectorAll( '.gk-video__frame[data-yt]' ).forEach( function ( frame ) {
		var button = frame.querySelector( '.gk-video__play' );
		if ( ! button ) {
			return;
		}
		button.addEventListener( 'click', function () {
			var id = frame.getAttribute( 'data-yt' );
			if ( ! /^[A-Za-z0-9_-]{11}$/.test( id ) ) {
				return;
			}
			var iframe = document.createElement( 'iframe' );
			iframe.src = 'https://www.youtube-nocookie.com/embed/' + id + '?autoplay=1&rel=0';
			iframe.title = button.querySelector( '.gk-video__title' ).textContent;
			iframe.allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen';
			iframe.allowFullscreen = true;
			iframe.referrerPolicy = 'strict-origin-when-cross-origin';
			frame.replaceChild( iframe, button );
			iframe.focus();
		} );
	} );
} )();
