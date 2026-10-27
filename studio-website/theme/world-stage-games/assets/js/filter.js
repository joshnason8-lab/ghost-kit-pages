/**
 * The region chips above the game cards: show only the games from one region. Without this script every game shows
 * and the chips stay hidden, so nothing is lost if it doesn't load.
 */
( function () {
	document.querySelectorAll( '.gk-filter' ).forEach( function ( bar ) {
		var section = bar.closest( '.gk-games' );
		if ( ! section ) {
			return;
		}
		var cards = section.querySelectorAll( '.gk-card:not(.gk-card--more)' );
		var status = section.querySelector( '.gk-filter__status' );
		var chips = bar.querySelectorAll( '.gk-chip' );

		chips.forEach( function ( chip ) {
			chip.addEventListener( 'click', function () {
				var region = chip.getAttribute( 'data-region' );
				var shown = 0;
				chips.forEach( function ( c ) {
					c.setAttribute( 'aria-pressed', c === chip ? 'true' : 'false' );
				} );
				cards.forEach( function ( card ) {
					var match = region === 'all' || card.classList.contains( 'gk-r-' + region );
					card.hidden = ! match;
					if ( match ) {
						shown++;
					}
				} );
				if ( status ) {
					status.textContent = shown === 1 ? '1 game shown' : shown + ' games shown';
				}
			} );
		} );
		bar.hidden = false;
	} );
} )();
