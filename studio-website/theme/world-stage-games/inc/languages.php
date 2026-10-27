<?php
/**
 * The site in the games' languages, through Google Translate.
 *
 * The site is written in English. The footer's language menu lists the 54 languages the games are played in, each
 * by its own name, and opens the page in Google Translate's web view (<site>.translate.goog) in that language. A
 * visitor whose browser asks for one of those languages also gets a one-tap suggestion at the bottom of the page.
 * Nothing goes to Google until the visitor chooses a language; the Privacy policy page says so. English stays the
 * official text, which matters most for the privacy policies.
 *
 * @package world-stage-games
 */

defined( 'ABSPATH' ) || exit;

/**
 * The games' languages (the union of every game's translations): Google Translate code => the language's own name.
 * English is the site's own language and isn't listed.
 */
function ghostkit_languages() {
	return array(
		'af'    => 'Afrikaans',
		'as'    => 'অসমীয়া',
		'bn'    => 'বাংলা',
		'my'    => 'မြန်မာ',
		'ny'    => 'Chichewa',
		'zh-CN' => '中文',
		'cs'    => 'Čeština',
		'da'    => 'Dansk',
		'et'    => 'Eesti',
		'fj'    => 'Na Vosa Vakaviti',
		'tl'    => 'Filipino',
		'fi'    => 'Suomi',
		'fr'    => 'Français',
		'de'    => 'Deutsch',
		'gu'    => 'ગુજરાતી',
		'hi'    => 'हिन्दी',
		'id'    => 'Bahasa Indonesia',
		'ga'    => 'Gaeilge',
		'it'    => 'Italiano',
		'ja'    => '日本語',
		'kn'    => 'ಕನ್ನಡ',
		'km'    => 'ខ្មែរ',
		'ko'    => '한국어',
		'lo'    => 'ລາວ',
		'lv'    => 'Latviešu',
		'lg'    => 'Luganda',
		'ms'    => 'Bahasa Melayu',
		'ml'    => 'മലയാളം',
		'mr'    => 'मराठी',
		'mi'    => 'Te Reo Māori',
		'ne'    => 'नेपाली',
		'no'    => 'Norsk',
		'or'    => 'ଓଡ଼ିଆ',
		'pl'    => 'Polski',
		'pt'    => 'Português',
		'pa'    => 'ਪੰਜਾਬੀ',
		'sm'    => 'Gagana Sāmoa',
		'st'    => 'Sesotho',
		'tn'    => 'Setswana',
		'sn'    => 'chiShona',
		'si'    => 'සිංහල',
		'sk'    => 'Slovenčina',
		'es'    => 'Español',
		'sw'    => 'Kiswahili',
		'sv'    => 'Svenska',
		'ta'    => 'தமிழ்',
		'te'    => 'తెలుగు',
		'th'    => 'ไทย',
		'to'    => 'Lea Faka-Tonga',
		'vi'    => 'Tiếng Việt',
		'cy'    => 'Cymraeg',
		'xh'    => 'isiXhosa',
		'zu'    => 'isiZulu',
	);
}

/**
 * The address of a page of this site in Google Translate's web view, in language $lang. For
 * https://worldstagegames.com/games/ in Hindi: https://worldstagegames-com.translate.goog/games/?_x_tr_sl=en&_x_tr_tl=hi&…
 */
function ghostkit_translate_url( $url, $lang ) {
	$p = wp_parse_url( $url );
	if ( empty( $p['host'] ) ) {
		return '';
	}
	// translate.goog writes the host with "-" for "." and "--" for "-".
	$host  = str_replace( '.', '-', str_replace( '-', '--', $p['host'] ) ) . '.translate.goog';
	$query = isset( $p['query'] ) ? $p['query'] . '&' : '';
	return 'https://' . $host . ( $p['path'] ?? '/' ) . '?' . $query . http_build_query(
		array(
			'_x_tr_sl'  => 'en',
			'_x_tr_tl'  => $lang,
			'_x_tr_hl'  => $lang,
			'_x_tr_pto' => 'wapp',
		)
	);
}

/** The address of the page being shown. */
function ghostkit_current_url() {
	if ( is_singular() ) {
		return get_permalink();
	}
	return home_url( wp_unslash( $_SERVER['REQUEST_URI'] ?? '/' ) ); // phpcs:ignore WordPress.Security.ValidatedSanitizedInput -- only parsed and escaped.
}

/**
 * [ghostkit_languages]: the footer's language menu. A disclosure ("🌐 Language") that opens a list of every language,
 * each a link to this page in Google Translate.
 */
add_shortcode(
	'ghostkit_languages',
	function () {
		$here  = ghostkit_current_url();
		$items = '';
		foreach ( ghostkit_languages() as $code => $name ) {
			$items .= sprintf(
				'<li><a href="%s" hreflang="%s" lang="%s" rel="nofollow noopener">%s</a></li>',
				esc_url( ghostkit_translate_url( $here, $code ) ),
				esc_attr( $code ),
				esc_attr( $code ),
				esc_html( $name )
			);
		}
		return '<details class="gk-lang"><summary><span aria-hidden="true">🌐</span> Language: English</summary>'
			. '<div class="gk-lang__panel"><p class="gk-lang__note">The site is written in English. Choose a language to read '
			. 'this page with Google Translate (machine translation; the English text is the official version).</p>'
			. '<ul class="gk-lang__list">' . $items . '</ul></div></details>';
	}
);

// The one-tap suggestion for browsers set to one of the languages: the list goes to the page, the script decides.
add_action(
	'wp_enqueue_scripts',
	function () {
		wp_enqueue_script(
			'ghostkit-language',
			get_theme_file_uri( 'assets/js/language.js' ),
			array(),
			GHOSTKIT_VERSION,
			array( 'strategy' => 'defer', 'in_footer' => true )
		);
		wp_localize_script( 'ghostkit-language', 'ghostkitLanguages', ghostkit_languages() );
	}
);
