"""The sport pages (/sports/<sport>/) and the Sports index, from content-src/sports/<sport>.md.

Each file is JSON front matter (photos with their licences, verified videos, sources) and a small Markdown body; see
content-src/sports/FORMAT.md. Photos are copied into the theme as WebP and credited under each picture; videos load
from YouTube's privacy-enhanced domain only when the visitor presses play."""

import html
import json
import os
import re

from PIL import Image

from blocks import buttons, esc, esc_attr, grid, group, heading, image, lst, paragraph, raw_html
import diagrams

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.dirname(HERE)
SRC = os.path.join(SITE, "content-src", "sports")
THEME_IMG = os.path.join(SITE, "theme", "ghost-kit", "assets", "images", "sports")

# Sport page slug -> the game that plays it, in the order of the Sports index.
SPORTS = [("kabaddi", "kabaddi-raid"), ("hurling", "hurling-heroes"), ("sepak-takraw", "sepak-takraw-unleashed"),
          ("netball", "netball-unleashed"), ("kho-kho", "kho-kho-rush"), ("floorball", "floorball-unleashed"),
          ("ulama", "pok-ta-pok-rivals")]
SPORT_OF_GAME = {g: s for s, g in SPORTS}


def load(slug):
    path = os.path.join(SRC, slug + ".md")
    if not os.path.exists(path):
        return None
    text = open(path, encoding="utf-8").read()
    m = re.match(r"\s*---\s*\n(.*?)\n---\s*\n(.*)", text, re.S)
    meta = json.loads(m.group(1))
    meta["body"] = m.group(2)
    meta["slug"] = slug
    return meta


def inline(s):
    """The Markdown subset inside a line: links, bold, italic. Everything else is escaped."""
    out, pos = [], 0
    for m in re.finditer(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", s):
        out.append(_emph(esc(s[pos:m.start()])))
        out.append('<a href="%s">%s</a>' % (esc_attr(m.group(2)), _emph(esc(m.group(1)))))
        pos = m.end()
    out.append(_emph(esc(s[pos:])))
    return "".join(out)


def _emph(s):
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    return re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", s)


def photo_key(slug, pid):
    return "sport-%s-%s" % (slug, pid)


def credit_html(p):
    return 'Photo: <a href="%s">%s</a>, <a href="%s">%s</a>, via Wikimedia Commons.' % (
        esc_attr(p["source_url"]), esc(p["author"]), esc_attr(p["licence_url"]), esc(p["licence"]))


def photo_block(slug, p):
    cap = "%s %s" % (inline(p["caption"]).rstrip(), credit_html(p)) if p.get("caption") else credit_html(p)
    return image(photo_key(slug, p["id"]), p["alt"], size="large", cls="gk-photo", caption=cap)


def video_block(v):
    vid = v["youtube_id"]
    assert re.fullmatch(r"[A-Za-z0-9_-]{11}", vid), vid
    return raw_html(
        '<figure class="gk-video"><div class="gk-video__frame" data-yt="%s">'
        '<button type="button" class="gk-video__play" aria-label="Play video: %s (from YouTube)">'
        '<span class="gk-video__icon" aria-hidden="true">▶</span>'
        '<span class="gk-video__title">%s</span>'
        '<span class="gk-video__note">%s · plays from YouTube when you press play</span></button></div>'
        '<figcaption class="wp-element-caption">%s <a href="https://www.youtube.com/watch?v=%s">Watch on YouTube</a>.</figcaption>'
        '</figure>' % (vid, esc_attr(v["title"]), esc(v["title"]), esc(v["channel"]), inline(v.get("why", "")), vid))


def diagram_block(slug):
    svg, caption = diagrams.DIAGRAMS[slug]()
    return raw_html('<figure class="gk-diagram">%s<figcaption class="wp-element-caption">%s</figcaption></figure>' % (
        svg, esc(caption)))


def body_blocks(meta):
    photos = {p["id"]: p for p in meta.get("photos", [])}
    videos = {v["id"]: v for v in meta.get("videos", [])}
    out, para, items, ordered = [], [], [], False

    def flush():
        nonlocal para, items
        if para:
            out.append(paragraph(inline(" ".join(para))))
            para = []
        if items:
            out.append(lst([inline(i) for i in items], ordered=ordered))
            items = []

    for raw in meta["body"].split("\n"):
        line = raw.rstrip()
        s = line.strip()
        ph = re.fullmatch(r"\{\{(photo|video):(\w+)\}\}|\{\{diagram\}\}", s)
        if ph:
            flush()
            if s == "{{diagram}}":
                out.append(diagram_block(meta["slug"]))
            elif ph.group(1) == "photo":
                if ph.group(2) in photos:
                    out.append(photo_block(meta["slug"], photos[ph.group(2)]))
            elif ph.group(2) in videos:
                out.append(video_block(videos[ph.group(2)]))
            continue
        if not s:
            flush()
            continue
        h = re.match(r"(#{2,3})\s+(.*)", s)
        if h:
            flush()
            out.append(heading(len(h.group(1)), inline(h.group(2))))
            continue
        li = re.match(r"(-|\d+\.)\s+(.*)", s)
        if li:
            if para:
                flush()
            this_ordered = li.group(1) != "-"
            if items and this_ordered != ordered:
                flush()
            ordered = this_ordered
            items.append(li.group(2))
            continue
        if items and raw.startswith("  "):
            items[-1] += " " + s
            continue
        if items:
            flush()
        para.append(s)
    flush()
    # Placeholders the author used but didn't define are an error, not a silent gap.
    for kind, ids in (("photo", photos), ("video", videos)):
        for pid in re.findall(r"\{\{%s:(\w+)\}\}" % kind, meta["body"]):
            assert pid in ids, (meta["slug"], kind, pid)
    return out


def word_count(meta):
    text = re.sub(r"\{\{[^}]+\}\}|[#*\[\]()]|https?://\S+", " ", meta["body"])
    return len(text.split())


def page_sport(meta, game):
    out = body_blocks(meta)
    s = game["slug"]
    out.append(heading(2, "Play it in our game", anchor="play"))
    out.append(group([
        image(s + "-screenshot-1", "In-game: " + _shot_alt(s), size="large",
              caption="In-game: %s, from the Android beta." % esc(game["name"])),
        paragraph("<strong>%s</strong>: %s" % (esc(game["name"]), esc(game["short_description"]))),
        buttons([("Play %s →" % esc(game["name"]), game["url"], None), ("Join the beta", game["beta_url"], "outline")]),
    ], cls="gk-play-cta", layout={"type": "default"}))
    out.append(heading(2, "Sources"))
    out.append(lst(['<a href="%s">%s</a>' % (esc_attr(x["url"]), esc(x["title"])) for x in meta.get("sources", [])],
                   cls="gk-sources"))
    if meta.get("videos"):
        out.append(paragraph("Videos belong to their channels and play from YouTube's privacy-enhanced mode "
                             '(youtube-nocookie.com) only when you press play. See the <a href="/privacy/">privacy '
                             "policy</a>.", cls="gk-small gk-muted"))
    return "\n\n".join(out)


_SHOT_ALTS = {}


def _shot_alt(game_slug):
    return _SHOT_ALTS.get(game_slug, "a match")


def page_index(entries):
    cards = []
    for meta, game in entries:
        first = (meta.get("photos") or [None])[0]
        img = image(photo_key(meta["slug"], first["id"]), "", size="medium_large") if first else \
            image(game["slug"] + "-feature", "", size="large")
        cards.append(group([
            group([img], cls="gk-card__art"),
            group([
                heading(3, '<a href="/sports/%s/">%s</a>' % (meta["slug"], esc(meta.get("title") or meta["sport"])),
                        cls="gk-card__title"),
                paragraph(esc(meta["summary"]), cls="gk-card__blurb"),
                lst(["Our game: " + esc(game["name"])], cls="gk-meta"),
            ], cls="gk-card__text gk-card__body", layout={"type": "flex", "orientation": "vertical"}),
        ], cls="gk-card gk-card--sport"))
    return "\n\n".join([
        group([
            heading(1, "The sports", cls="gk-page-title"),
            paragraph("Every game we make is a real sport, played somewhere in the world today. Here is each one: where "
                      "it comes from, how it's played and where to watch it.", cls="gk-lead"),
        ], align="wide", layout={"type": "default"}),
        group([grid(cards, cls="gk-grid", min_width="17rem", count=3)], cls="gk-games", align="wide",
              layout={"type": "default"}),
    ])


def assets(entries):
    """Copies each photo into the theme as WebP (at most 1600 px wide) and lists it for the Media Library."""
    os.makedirs(THEME_IMG, exist_ok=True)
    out = []
    for meta, game in entries:
        for p in meta.get("photos", []):
            src = os.path.join(SRC, p["file"])
            name = "%s-%s.webp" % (meta["slug"], p["id"])
            dst = os.path.join(THEME_IMG, name)
            if not os.path.exists(dst) or os.path.getmtime(dst) < os.path.getmtime(src):
                im = Image.open(src)
                im = im.convert("RGB")
                if im.width > 1600:
                    im = im.resize((1600, round(im.height * 1600 / im.width)), Image.LANCZOS)
                im.save(dst, quality=74, method=6)
            out.append({"key": photo_key(meta["slug"], p["id"]), "file": "sports/" + name, "alt": p["alt"],
                        "title": "%s: %s" % (meta["sport"], p.get("caption") or p["alt"]),
                        "caption": html.unescape(re.sub(r"<[^>]+>", "", credit_html(p)))})
    return out


def credits_markdown(entries):
    lines = ["# Media credits", "",
             "Every photo on the website's sport pages, with its author and licence. All come from Wikimedia "
             "Commons under licences that allow reuse; each is credited under the photo on its page too. "
             "This file is written by `tools/build_content.py`; edit the sport's `content-src/sports/<sport>.md` "
             "instead.", ""]
    for meta, game in entries:
        lines += ["## %s (`/sports/%s/`)" % (meta["sport"], meta["slug"]), ""]
        for p in meta.get("photos", []):
            lines.append("- **%s**: %s. Author: %s. Licence: [%s](%s). Source: <%s>. File: `theme/ghost-kit/assets/images/sports/%s-%s.webp`." % (
                p.get("caption") or p["alt"], p["alt"], p["author"], p["licence"], p["licence_url"], p["source_url"],
                meta["slug"], p["id"]))
        if meta.get("videos"):
            lines.append("")
            for v in meta["videos"]:
                lines.append("- Video (embedded, not copied): \"%s\" by %s, https://www.youtube.com/watch?v=%s" % (
                    v["title"], v["channel"], v["youtube_id"]))
        if not meta.get("photos"):
            lines.append("- No photos yet.")
        lines.append("")
    lines += ["## The games' own pictures", "",
              "The icons, title art and screenshots on the site come from the games themselves (each game's "
              "`store/graphics/` folder on its branch). On the sport pages they are labelled *In-game*.", ""]
    return "\n".join(lines)


def licences_list(entries):
    items = []
    for meta, game in entries:
        for p in meta.get("photos", []):
            items.append('%s (<a href="/sports/%s/">%s</a>): %s' % (
                esc(p.get("caption") or p["alt"]), meta["slug"], esc(meta["sport"]), credit_html(p)))
    return items
