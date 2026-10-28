/**
 * If the visitor's browser prefers one of the games' languages (and not English), offer the page in that language with
 * one tap, through Google Translate. It is only an offer: nothing is sent to Google until the visitor taps it, and
 * closing it hides it for good on this device.
 */
( function () {
	var names = window.ghostkitLanguages || {};
	var host = location.hostname;
	if ( /\.translate\.goog$/.test( host ) ) {
		return;
	}
	try {
		if ( localStorage.getItem( 'gk-lang-dismissed' ) ) {
			return;
		}
	} catch ( e ) {}

	// The first language the browser asks for that we can offer; stop at English, which the site already is.
	var code = null;
	var wanted = navigator.languages && navigator.languages.length ? navigator.languages : [ navigator.language || 'en' ];
	for ( var i = 0; i < wanted.length && ! code; i++ ) {
		var tag = String( wanted[ i ] ).toLowerCase();
		var base = tag.split( '-' )[ 0 ];
		if ( base === 'en' ) {
			return;
		}
		if ( base === 'zh' ) {
			code = 'zh-CN';
		} else if ( base === 'fil' ) {
			code = 'tl';
		} else if ( base === 'nb' || base === 'nn' ) {
			code = 'no';
		} else if ( names[ base ] ) {
			code = base;
		}
	}
	if ( ! code ) {
		return;
	}

	var gHost = host.replace( /-/g, '--' ).replace( /\./g, '-' ) + '.translate.goog';
	var query = location.search ? location.search.slice( 1 ) + '&' : '';
	var url = 'https://' + gHost + location.pathname + '?' + query + '_x_tr_sl=en&_x_tr_tl=' + encodeURIComponent( code ) +
		'&_x_tr_hl=' + encodeURIComponent( code ) + '&_x_tr_pto=wapp' + location.hash;

	var bar = document.createElement( 'div' );
	bar.className = 'gk-langbar';
	bar.setAttribute( 'role', 'region' );
	bar.setAttribute( 'aria-label', 'Language' );

	var link = document.createElement( 'a' );
	link.href = url;
	link.rel = 'nofollow noopener';
	link.lang = code;
	link.className = 'gk-langbar__go';
	link.innerHTML = '<span aria-hidden="true">🌐</span> ';
	link.appendChild( document.createTextNode( names[ code ] + ' →' ) );

	var hint = document.createElement( 'span' );
	hint.className = 'gk-langbar__hint';
	hint.textContent = 'Read this page in your language (Google Translate)';

	var close = document.createElement( 'button' );
	close.type = 'button';
	close.className = 'gk-langbar__close';
	close.setAttribute( 'aria-label', 'No thanks, keep English' );
	close.textContent = '×';
	close.addEventListener( 'click', function () {
		bar.remove();
		try {
			localStorage.setItem( 'gk-lang-dismissed', '1' );
		} catch ( e ) {}
	} );

	bar.appendChild( link );
	bar.appendChild( hint );
	bar.appendChild( close );
	document.body.appendChild( bar );
} )();
