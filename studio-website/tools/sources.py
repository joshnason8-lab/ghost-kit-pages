"""Reads each game's own privacy policy and help page, read-only, from its branch (git show), and turns them into
sections: a list of (heading, [html blocks]) where an html block is ("p", inner_html) or ("ul", [li_html, ...]) or
("h3", text). The words are copied as written; only line wraps are joined and links made clickable."""

import html
import json
import re
import subprocess

REPO = __file__.rsplit("/studio-website/", 1)[0]


def show(ref):
    return subprocess.run(["git", "-C", REPO, "show", ref], check=True, capture_output=True, text=True).stdout


def unwrap(text):
    """Joins hard-wrapped lines inside a paragraph (the sources wrap at 120 columns)."""
    return re.sub(r"\s*\n\s*", " ", text.strip())


def linkify(escaped):
    """Makes bare e-mail addresses and web addresses clickable. Input is already HTML-escaped plain text."""
    def url(m):
        u = m.group(0)
        trail = ""
        while u and u[-1] in ".,;:)":
            trail = u[-1] + trail
            u = u[:-1]
        href = u if u.startswith("http") else "https://" + u
        return '<a href="%s">%s</a>%s' % (href, u, trail)
    escaped = re.sub(r"https?://[^\s<]+|\bkabaddi-raid-beta\.netlify\.app\b", url, escaped)
    escaped = re.sub(r"(?<![\w/@.])([\w.+-]+@[\w-]+\.[\w.]+[a-z])", r'<a href="mailto:\1">\1</a>', escaped)
    return escaped


def para(text):
    return ("p", linkify(html.escape(unwrap(text), quote=False)))


def bbcode_sections(text):
    """Godot rich text: '[b]Heading[/b]\\nparagraph' blocks. Returns (title_line, intro_paragraphs, sections)."""
    parts = re.split(r"\[b\](.*?)\[/b\]\n?", text)
    # parts: ['', title, body, heading, body, ...]
    title = parts[1]
    intro = [para(x) for x in re.split(r"\n\s*\n", parts[2].strip()) if x.strip()]
    sections = []
    for i in range(3, len(parts), 2):
        body = [para(x) for x in re.split(r"\n\s*\n", parts[i + 1].strip()) if x.strip()]
        sections.append((parts[i], body))
    return title, intro, sections


def md_sections(text):
    """Markdown policy: '# Title', a date paragraph, then '## Heading' sections with paragraphs and '- ' lists."""
    lines = text.strip().split("\n")
    title = lines[0].lstrip("# ").strip()
    rest = "\n".join(lines[1:])
    chunks = re.split(r"^## (.+)$", rest, flags=re.M)
    intro = _md_blocks(chunks[0])
    sections = [(chunks[i].strip(), _md_blocks(chunks[i + 1])) for i in range(1, len(chunks), 2)]
    return title, intro, sections


def _md_blocks(text):
    out = []
    for block in re.split(r"\n\s*\n", text.strip()):
        if not block.strip():
            continue
        if block.lstrip().startswith("- "):
            items = [unwrap(x) for x in re.split(r"^\s*- ", block, flags=re.M) if x.strip()]
            out.append(("ul", [_md_inline(x) for x in items]))
        else:
            out.append(("p", _md_inline(unwrap(block))))
    return out


def _md_inline(s):
    s = linkify(html.escape(s, quote=False))
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<!\w)\*([^*]+)\*(?!\w)", r"<em>\1</em>", s)
    return s


def gd_const(src, name):
    m = re.search(r'const %s := """(.*?)"""' % name, src, re.S)
    return m.group(1)


def gd_str(src, name):
    return re.search(r'const %s := "([^"]*)"' % name, src).group(1)


# ---------------------------------------------------------------------------------------------------------- privacy

def privacy(slug):
    """Returns {"title", "updated", "intro": [blocks], "sections": [(heading, [blocks])], "source"}."""
    if slug == "kabaddi-raid":
        ref = "origin/claude/kabaddi-game-concept-asnz07:kabaddi-game/ui/privacy_screen.gd"
        src = show(ref)
        text = gd_const(src, "TEXT") % (gd_str(src, "UPDATED"), gd_str(src, "CONTACT"))
        title, intro, sections = bbcode_sections(text)
    elif slug == "kho-kho-rush":
        ref = "origin/claude/kho-kho-game:kho-kho-game/ui/privacy_screen.gd"
        src = show(ref)
        email = re.search(r'CONTACT_EMAIL := "([^"]+)"', show("origin/claude/kho-kho-game:kho-kho-game/autoload/game.gd")).group(1)
        text = gd_const(src, "POLICY").replace("{date}", gd_str(src, "UPDATED")).replace("{email}", email)
        title, intro, sections = bbcode_sections(text)
    elif slug in ("netball-unleashed", "floorball-unleashed", "sepak-takraw-unleashed"):
        ref = {
            "netball-unleashed": "origin/claude/netball-game:netball-game/PRIVACY.md",
            "floorball-unleashed": "origin/claude/floorball-game:floorball-game/docs/PRIVACY.md",
            "sepak-takraw-unleashed": "origin/claude/kind-clarke-3g5fqs:takraw-smash/PRIVACY.md",
        }[slug]
        title, intro, sections = md_sections(show(ref))
    elif slug in ("hurling-heroes", "pok-ta-pok-rivals"):
        branch, folder, keys = {
            "hurling-heroes": ("hurling-game", "hurling-game",
                               ["PRIV_SUMMARY", "PRIV_KEPT", "PRIV_HD", "PRIV_PERMS", "PRIV_CHILDREN", "PRIV_CHANGES", "PRIV_CONTACT"]),
            "pok-ta-pok-rivals": ("pok-ta-pok-game", "pok-ta-pok-game",
                                  ["PRIV_SUMMARY", "PRIV_INTERNET", "PRIV_KEPT", "PRIV_PERMS", "PRIV_CHILDREN", "PRIV_CHANGES", "PRIV_CONTACT"]),
        }[slug]
        ref = "origin/claude/%s:%s/i18n/src/en.json" % (branch, folder)
        s = json.loads(show(ref))
        title = None
        intro = [para(s["PRIV_DATE"])]
        sections = [(s[k], [para(s[k + "_TEXT"])]) for k in keys]
    else:
        raise KeyError(slug)

    # Find the "Last updated <date>" sentence wherever the source put it.
    flat = json.dumps([intro, sections])
    updated = re.search(r"Last updated (\d+ \w+ \d{4})", flat).group(1)
    return {"title": title, "updated": updated, "intro": intro, "sections": sections, "source": ref}


# ---------------------------------------------------------------------------------------------------------- support

SUPPORT_SRC = {
    "kabaddi-raid": "origin/claude/kabaddi-game-concept-asnz07:kabaddi-raid/support.html",
    "sepak-takraw-unleashed": "origin/claude/kind-clarke-3g5fqs:takraw-smash/support.html",
    "netball-unleashed": "origin/claude/netball-game:netball-unleashed/support.html",
    "kho-kho-rush": "origin/claude/kho-kho-game:khamba-dash/support.html",
    "hurling-heroes": "origin/claude/hurling-game:ash-and-leather/support.html",
    "floorball-unleashed": "origin/claude/floorball-game:floorball-unleashed/support.html",
    "pok-ta-pok-rivals": "origin/claude/pok-ta-pok-game:pok-ta-pok-rivals/support.html",
}


def support(slug, name):
    """The game's own web help page, as blocks: [("h2"|"h3", text) | ("p", html) | ("ul", [html])]."""
    ref = SUPPORT_SRC[slug]
    page = show(ref)
    body = page.split("<body", 1)[1]
    body = body.split("</h1>", 1)[1]                      # drop the kicker and the page's own h1
    body = re.split(r"<footer", body)[0]
    blocks = []
    for m in re.finditer(r"<(h2|h3|p|ul)[^>]*>(.*?)</\1>", body, re.S):
        tag, inner = m.group(1), m.group(2)
        inner = _fix_links(slug, name, inner)
        if tag in ("h2", "h3"):
            blocks.append((tag, unwrap(re.sub(r"<[^>]+>", "", inner))))
        elif tag == "p":
            blocks.append(("p", unwrap(inner)))
        else:
            items = [unwrap(x) for x in re.findall(r"<li[^>]*>(.*?)</li>", inner, re.S)]
            blocks.append(("ul", items))
    return {"blocks": blocks, "source": ref}


def _fix_links(slug, name, s):
    s = s.replace('href="privacy.html"', 'href="/games/%s/privacy/"' % slug)
    s = s.replace('href="support.html"', 'href="/games/%s/support/"' % slug)
    s = s.replace('href="./"', 'href="/games/%s/"' % slug)
    # The help pages were written before some games were renamed; the e-mail subject names the game as it is now.
    s = re.sub(r'(mailto:[^"?]+)\?subject=[^"]*', lambda m: m.group(1) + "?subject=" + name.replace(" ", "%20") + "%20help", s)
    return s
