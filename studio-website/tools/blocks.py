"""Small helpers that write WordPress block markup the way the block editor saves it, so pages open in the editor
without "unexpected content" warnings. Images use tokens the theme's setup replaces with the real attachment:
%%ID:key%% (the attachment ID) and %%URL:key:size%% (its URL at that size)."""

import html
import json


def _attrs(d):
    d = {k: v for k, v in d.items() if v not in (None, "", [], {})}
    if not d:
        return ""
    s = json.dumps(d, ensure_ascii=False, separators=(",", ":"))
    # The image ID is a number in the block's attributes; write the token bare so the setup's replacement is a number.
    s = s.replace('"__ID__', "").replace('__DI__"', "")
    return " " + s


def _cls(*names):
    names = [n for n in names if n]
    return (' class="%s"' % " ".join(names)) if names else ""


def esc(s):
    return html.escape(s, quote=False)


def esc_attr(s):
    return html.escape(s, quote=True)


def paragraph(inner, cls=None, anchor=None):
    a = _attrs({"anchor": anchor, "className": cls})
    idattr = ' id="%s"' % anchor if anchor else ""
    return "<!-- wp:paragraph%s -->\n<p%s%s>%s</p>\n<!-- /wp:paragraph -->" % (a, idattr, _cls(cls), inner)


def heading(level, inner, cls=None, anchor=None):
    a = _attrs({"level": level if level != 2 else None, "anchor": anchor, "className": cls})
    idattr = ' id="%s"' % anchor if anchor else ""
    return '<!-- wp:heading%s -->\n<h%d%s%s>%s</h%d>\n<!-- /wp:heading -->' % (
        a, level, idattr, _cls("wp-block-heading", cls), inner, level)


def lst(items, cls=None, ordered=False):
    a = _attrs({"ordered": True if ordered else None, "className": cls})
    tag = "ol" if ordered else "ul"
    lis = "\n\n".join("<!-- wp:list-item -->\n<li>%s</li>\n<!-- /wp:list-item -->" % i for i in items)
    return "<!-- wp:list%s -->\n<%s%s>%s</%s>\n<!-- /wp:list -->" % (a, tag, _cls("wp-block-list", cls), lis, tag)


def group(inner, cls=None, tag=None, align=None, layout=None, anchor=None):
    a = _attrs({"tagName": tag if tag and tag != "div" else None, "align": align, "anchor": anchor,
                "className": cls, "layout": layout})
    t = tag or "div"
    idattr = ' id="%s"' % anchor if anchor else ""
    return "<!-- wp:group%s -->\n<%s%s%s>%s</%s>\n<!-- /wp:group -->" % (
        a, t, idattr, _cls("wp-block-group", "align" + align if align else None, cls), "\n\n".join(inner), t)


def columns(cols, cls=None, align=None):
    """cols: list of (width or None, [inner blocks])."""
    a = _attrs({"align": align, "className": cls})
    out = []
    for width, inner in cols:
        ca = _attrs({"width": width})
        style = ' style="flex-basis:%s"' % width if width else ""
        out.append("<!-- wp:column%s -->\n<div class=\"wp-block-column\"%s>%s</div>\n<!-- /wp:column -->" % (
            ca, style, "\n\n".join(inner)))
    return "<!-- wp:columns%s -->\n<div%s>%s</div>\n<!-- /wp:columns -->" % (
        a, _cls("wp-block-columns", "align" + align if align else None, cls), "\n\n".join(out))


def image(key, alt, size="large", cls=None, caption=None, lightbox=False, href=None):
    a = {"id": "__ID__%%ID:" + key + "%%__DI__", "sizeSlug": size,
         "linkDestination": "custom" if href else "none", "className": cls}
    if lightbox:
        a["lightbox"] = {"enabled": True}
    img = '<img src="%%%%URL:%s:%s%%%%" alt="%s" class="wp-image-%%%%ID:%s%%%%"/>' % (key, size, esc_attr(alt), key)
    if href:
        img = '<a href="%s">%s</a>' % (esc_attr(href), img)
    cap = '<figcaption class="wp-element-caption">%s</figcaption>' % caption if caption else ""
    return "<!-- wp:image%s -->\n<figure%s>%s%s</figure>\n<!-- /wp:image -->" % (
        _attrs(a), _cls("wp-block-image", "size-" + size, cls), img, cap)


def gallery(images, cls=None, columns_n=4):
    """images: list of (key, alt). Each opens full size in the lightbox."""
    a = _attrs({"columns": columns_n, "linkTo": "none", "className": cls})
    inner = "\n\n".join(image(k, alt, lightbox=True) for k, alt in images)
    return "<!-- wp:gallery%s -->\n<figure%s>%s</figure>\n<!-- /wp:gallery -->" % (
        a, _cls("wp-block-gallery", "has-nested-images", "columns-%d" % columns_n, "is-cropped", cls), inner)


def buttons(items, cls=None):
    """items: list of (text, href, style) where style is None or "outline"."""
    out = []
    for text, href, style in items:
        bcls = "is-style-outline" if style == "outline" else None
        out.append('<!-- wp:button%s -->\n<div%s><a class="wp-block-button__link wp-element-button" href="%s">%s</a></div>\n<!-- /wp:button -->' % (
            _attrs({"className": bcls}), _cls("wp-block-button", bcls), esc_attr(href), text))
    return "<!-- wp:buttons%s -->\n<div%s>%s</div>\n<!-- /wp:buttons -->" % (
        _attrs({"className": cls}), _cls("wp-block-buttons", cls), "\n\n".join(out))


def table(rows, cls=None):
    """rows: list of (label, value_html). The label cell is a row header."""
    body = "".join("<tr><th>%s</th><td>%s</td></tr>" % (esc(k), v) for k, v in rows)
    return '<!-- wp:table%s -->\n<figure%s><table class="has-fixed-layout"><tbody>%s</tbody></table></figure>\n<!-- /wp:table -->' % (
        _attrs({"className": cls}), _cls("wp-block-table", cls), body)


def separator():
    return '<!-- wp:separator -->\n<hr class="wp-block-separator has-alpha-channel-opacity"/>\n<!-- /wp:separator -->'


def raw_html(s):
    return "<!-- wp:html -->\n%s\n<!-- /wp:html -->" % s


def grid(inner, cls=None, min_width="16rem", align=None, count=None):
    """A responsive grid: at most `count` columns, each at least `min_width` wide."""
    layout = {"type": "grid", "columnCount": count, "minimumColumnWidth": min_width} if count else \
        {"type": "grid", "minimumColumnWidth": min_width}
    return group(inner, cls=cls, align=align, layout=layout)


def row(inner, cls=None, wrap=True, justify=None):
    layout = {"type": "flex", "flexWrap": "wrap" if wrap else "nowrap"}
    if justify:
        layout["justifyContent"] = justify
    return group(inner, cls=cls, layout=layout)


def stack(inner, cls=None):
    return group(inner, cls=cls, layout={"type": "flex", "orientation": "vertical"})
