# Sport page format

One file per sport: `content-src/sports/<slug>.md`. `tools/build_content.py` turns it into the page `/sports/<slug>/`.

The file starts with a JSON front matter block between two lines of `---`, then the body in a small Markdown subset.

```
---
{
  "sport": "Kabaddi",
  "slug": "kabaddi",
  "game_slug": "kabaddi-raid",
  "summary": "One or two sentences, max 155 characters, for search engines and the Sports index card.",
  "photos": [
    {"id": "p1", "file": "img/kabaddi-1.jpg", "commons_title": "File:Example.jpg",
     "source_url": "https://commons.wikimedia.org/wiki/File:Example.jpg",
     "author": "Exact author / credit line as Commons gives it", "licence": "CC BY-SA 4.0",
     "licence_url": "https://creativecommons.org/licenses/by-sa/4.0/",
     "alt": "What the photo shows, for screen readers", "caption": "Short visible caption"}
  ],
  "videos": [
    {"id": "v1", "youtube_id": "XXXXXXXXXXX", "title": "Title exactly as YouTube oEmbed gives it",
     "channel": "author_name exactly as oEmbed gives it", "why": "One line: what the viewer learns"}
  ],
  "sources": [
    {"title": "Kabaddi - Wikipedia", "url": "https://en.wikipedia.org/wiki/Kabaddi"}
  ]
}
---
## What is kabaddi?

Paragraph text. **bold**, *italic*, [a link](https://example.org).

{{photo:p1}}

## History and origins
...
### A sub-heading

- a bullet
- another

1. a numbered step
2. another

{{diagram}}

{{video:v1}}
```

Rules
- Only `##` and `###` headings, paragraphs, `- ` and `1. ` lists, `**bold**`, `*italic*`, `[text](url)`, and the
  placeholders `{{photo:ID}}`, `{{video:ID}}`, `{{diagram}}` each on a line of its own.
- No HTML, no tables, no images other than the placeholders.
- Do NOT write the "Play it in our game" section or the sources section: the build adds both from the front matter.
