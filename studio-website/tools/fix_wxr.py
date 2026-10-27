#!/usr/bin/env python3
"""Makes the exported WXR portable: keeps only the published pages and the theme's images, points each image at its
file on GitHub (pinned to a commit, so the address never changes) for Tools > Import to download, and swaps the
local test address for https://worldstagegames.com.

  python3 fix_wxr.py <exported.xml> <out.xml> <commit-sha>
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
THEME = os.path.join(os.path.dirname(HERE), "theme", "world-stage-games")
RAW = "https://raw.githubusercontent.com/joshnason8-lab/ghost-kit-pages/%s/studio-website/theme/world-stage-games/assets/images/"
LOCAL = "http://localhost:8881"

src, out, sha = sys.argv[1:4]
xml = open(src, encoding="utf-8").read()
files = {a["key"]: a["file"] for a in json.load(open(os.path.join(THEME, "inc", "content", "pages.json")))["assets"]}
files["site-logo"] = "logo.png"
raw = RAW % sha

head, rest = xml.split("<item>", 1)
items = ["<item>" + x for x in rest.split("<item>")]
tail = ""
items[-1], tail = items[-1].split("</channel>", 1)
tail = "</channel>" + tail

kept, remap = [], {}
for it in items:
    ptype = re.search(r"<wp:post_type><!\[CDATA\[(.*?)\]\]>", it).group(1)
    status = re.search(r"<wp:status><!\[CDATA\[(.*?)\]\]>", it).group(1)
    if ptype == "page" and status == "publish":
        kept.append(it)
    elif ptype == "attachment":
        key = re.search(r"<wp:meta_key><!\[CDATA\[_ghostkit_asset\]\]></wp:meta_key>\s*<wp:meta_value><!\[CDATA\[(.*?)\]\]>", it)
        if not key:
            continue
        url = re.search(r"<wp:attachment_url><!\[CDATA\[(.*?)\]\]>", it).group(1)
        new = raw + files[key.group(1)]
        # The stub (address without extension) lets the sized copies in the pages' content follow too.
        remap[url.rsplit(".", 1)[0]] = new.rsplit(".", 1)[0]
        it = it.replace(url, new)
        it = re.sub(r"<guid isPermaLink=\"false\">.*?</guid>", '<guid isPermaLink="false">%s</guid>' % new, it)
        kept.append(it)

body = "".join(kept)
for old in sorted(remap, key=len, reverse=True):
    body = body.replace(old, remap[old])
doc = head + body + tail
# Drop the menu/term lists in the header (the site uses none) and the local address.
doc = re.sub(r"\t<wp:(term|category|tag)>.*?</wp:\1>\n", "", doc, flags=re.S)
doc = doc.replace(LOCAL, "https://worldstagegames.com")
assert "localhost" not in doc
open(out, "w", encoding="utf-8").write(doc)
print("items: %d (pages %d, images %d)" % (len(kept), body.count("<wp:post_type><![CDATA[page]]>"),
                                            body.count("<wp:post_type><![CDATA[attachment]]>")))
