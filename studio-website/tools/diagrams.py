"""Simple court and pitch diagrams for the sport pages, drawn as inline SVG (a few KB each, sharp on every screen,
readable by screen readers through <title> and <desc>). Measurements are from each sport's rules; where a sport's
sizes vary, the caption says so.

Each function returns (svg, caption)."""

LINE = "#e8eef6"
LABEL = "#f2f4f8"
MUTED = "#9aa6b8"
ACCENT = "#ff8a1f"
TEAL = "#2bd4a4"


def _svg(slug, w, h, title, desc, body, pad=40):
    vb = "%g %g %g %g" % (-pad, -pad, w + 2 * pad, h + 2 * pad)
    return (
        '<svg class="gk-diagram__svg" viewBox="%s" role="img" aria-labelledby="%s-t %s-d" '
        'xmlns="http://www.w3.org/2000/svg" font-family="Inter, system-ui, sans-serif">'
        '<title id="%s-t">%s</title><desc id="%s-d">%s</desc>%s</svg>'
        % (vb, slug, slug, slug, title, slug, desc, body)
    )


def _t(x, y, s, size=26, fill=LABEL, anchor="middle", weight=600, rotate=None):
    rot = ' transform="rotate(%g %g %g)"' % (rotate, x, y) if rotate is not None else ""
    return ('<text x="%g" y="%g" font-size="%g" fill="%s" text-anchor="%s" font-weight="%d" '
            'dominant-baseline="middle"%s>%s</text>' % (x, y, size, fill, anchor, weight, rot, s))


def _line(x1, y1, x2, y2, stroke=LINE, w=4, dash=None):
    d = ' stroke-dasharray="%s"' % dash if dash else ""
    return '<line x1="%g" y1="%g" x2="%g" y2="%g" stroke="%s" stroke-width="%g"%s/>' % (x1, y1, x2, y2, stroke, w, d)


def _rect(x, y, w, h, fill="none", stroke=LINE, sw=4, rx=0):
    return '<rect x="%g" y="%g" width="%g" height="%g" fill="%s" stroke="%s" stroke-width="%g" rx="%g"/>' % (
        x, y, w, h, fill, stroke, sw, rx)


def kabaddi():
    # Men's court: 13 m x 10 m, plus a 1 m lobby on each side. Scale 60 px per metre.
    s = 60
    L, W, lob = 13 * s, 10 * s, 1 * s
    mid = L / 2
    b = [
        _rect(0, -lob, L, W + 2 * lob, fill="#24486e", stroke="none"),
        _rect(0, 0, L, W, fill="#2f6aa3", stroke=LINE),
        _line(0, -lob, L, -lob), _line(0, W + lob, L, W + lob),
        _line(0, -lob, 0, W + lob), _line(L, -lob, L, W + lob),
        _line(mid, -lob, mid, W + lob, stroke=ACCENT, w=7),
    ]
    for sign in (-1, 1):
        bx = mid + sign * 3.75 * s
        bo = mid + sign * 4.75 * s
        b += [_line(bx, 0, bx, W), _line(bo, 0, bo, W, dash="14 10")]
        b += [_t(bx - sign * 14, W * 0.28, "Baulk line", 22, rotate=-90), _t(bo + sign * 16, W * 0.72, "Bonus line", 22, rotate=-90)]
    b += [
        _t(mid, -lob - 22, "Midline", 24, ACCENT),
        _t(L / 4 - 20, W / 2, "Half A", 30, LABEL), _t(3 * L / 4 + 20, W / 2, "Half B", 30, LABEL),
        _t(mid, W + lob / 2, "Lobby (1 m)", 22, MUTED), _t(mid, -lob / 2, "Lobby (1 m)", 22, MUTED),
        _t(L / 2, W + lob + 34, "13 m", 24, MUTED), _t(-26, W / 2, "10 m", 24, MUTED, rotate=-90),
    ]
    svg = _svg("kabaddi", L, W + 2 * lob + 40, "A kabaddi court",
               "A rectangle 13 metres long and 10 metres wide, split in two halves by the midline. In each half a baulk "
               "line runs 3.75 metres from the midline and a bonus line 1 metre beyond it. A one-metre lobby strip "
               "runs along each side.", "".join(b), pad=70)
    return svg, ("The men's court under the international rules: 13 × 10 m, with a 1 m lobby on each side (in play "
                 "only during a struggle). The baulk line is 3.75 m from the midline and the bonus line 1 m beyond it. "
                 "Women's and junior courts are smaller.")


def kho_kho():
    # Simplified: a rectangle with a post at each end, the central lane between them, and the squares where the
    # chasers sit facing alternate ways. Not to scale.
    L, W = 1000, 520
    b = [_rect(0, 0, L, W, fill="#7a4a2a", stroke=LINE)]
    px1, px2 = 110, L - 110
    b += [_line(px1, 0, px1, W, dash="14 10"), _line(px2, 0, px2, W, dash="14 10")]
    b += [_rect(px1, W / 2 - 14, px2 - px1, 28, fill="#8f5a35", stroke=LINE, sw=3)]
    n = 8
    step = (px2 - px1) / (n + 1)
    for i in range(1, n + 1):
        x = px1 + i * step
        b.append(_line(x, 0, x, W, stroke="#d9c7b0", w=2))
        cy = W / 2 + (-34 if i % 2 else 34)
        b.append('<circle cx="%g" cy="%g" r="15" fill="%s"/>' % (x, cy, ACCENT))
        b.append('<path d="M%g %g l0 %g" stroke="%s" stroke-width="4"/>' % (x, cy, -24 if i % 2 else 24, LABEL))
    for x in (px1, px2):
        b.append('<circle cx="%g" cy="%g" r="16" fill="%s" stroke="%s" stroke-width="4"/>' % (x, W / 2, "#e9d8a6", "#3a2a1a"))
    b += [
        _t(px1, W / 2 - 56, "Post", 24), _t(px2, W / 2 - 56, "Post", 24),
        _t(L / 2, W / 2 + 92, "Central lane", 24, LABEL),
        _t(px1 / 2, W / 2 + 120, "Free zone", 22, MUTED, rotate=-90), _t((L + px2) / 2, W / 2 + 120, "Free zone", 22, MUTED, rotate=-90),
        _t(L / 2, -20, "Cross lanes: the chasers sit in the squares, facing alternate sides", 22, MUTED),
        '<circle cx="%g" cy="%g" r="15" fill="%s"/>' % (300, W - 70, TEAL), _t(330, W - 70, "Active chaser", 22, LABEL, "start"),
        '<circle cx="%g" cy="%g" r="15" fill="%s"/>' % (620, W - 70, ACCENT), _t(650, W - 70, "Sitting chasers", 22, LABEL, "start"),
        '<circle cx="%g" cy="%g" r="15" fill="%s"/>' % (430, 150, TEAL),
    ]
    svg = _svg("kho-kho", L, W, "A kho kho field",
               "A rectangle with a wooden post at each end. A central lane joins the two posts; cross lanes divide it "
               "into squares where the chasing team's players sit, facing alternate sides. Behind each post is a free "
               "zone.", "".join(b))
    return svg, ("Simplified, not to scale. A post stands at each end of the central lane; the chasers sit in the "
                 "squares along it, facing alternate sides. Field sizes differ between the classic nine-a-side game and "
                 "the newer seven-a-side formats.")


def hurling():
    # About 140 m x 85 m (rules allow 130–145 x 80–90). Scale 7 px per metre.
    s = 7
    L, W = 140 * s, 85 * s
    b = [_rect(0, 0, L, W, fill="#2f6b3a", stroke=LINE)]
    for i in range(0, 14):
        if i % 2:
            b.append('<rect x="%g" y="0" width="%g" height="%g" fill="#2a6033"/>' % (i * L / 14, L / 14, W))
    b.append(_rect(0, 0, L, W, stroke=LINE))
    cy = W / 2
    for end, sign in ((0, 1), (L, -1)):
        for m, lab in ((13, "13 m"), (20, "20 m"), (45, "45 m"), (65, "65 m")):
            x = end + sign * m * s
            b.append(_line(x, 0, x, W, w=3, dash=None if m in (13, 20, 65) else "10 8"))
            if end == 0:
                b.append(_t(x, -20 if m in (13, 45) else -48, lab, 22, MUTED))
        b.append(_rect(min(end, end + sign * 4.5 * s), cy - 7 * s, 4.5 * s, 14 * s, stroke=LINE, sw=3))
        b.append(_rect(min(end, end + sign * 13 * s), cy - 9.5 * s, 13 * s, 19 * s, stroke=LINE, sw=3))
        b.append(_line(end, cy - 3.25 * s, end, cy + 3.25 * s, stroke=ACCENT, w=12))
    b.append(_line(L / 2, 0, L / 2, W, w=3))
    b += [_t(L / 2 + 8, W + 30, "", 1, MUTED), _t(L / 2, -20, "Halfway", 22, MUTED),
          _t(L / 4, W + 30, "130–145 m", 24, MUTED), _t(-26, W / 2, "80–90 m", 24, MUTED, rotate=-90),
          _t(70, cy + 9.5 * s + 26, "Large rectangle", 20, LABEL, "start"),
          _t(L, W + 30, "Goal: posts 6.5 m apart, crossbar 2.5 m high", 20, ACCENT, "end")]
    svg = _svg("hurling", L, W + 20, "A hurling pitch",
               "A grass pitch about 140 metres long and 85 metres wide. At each end are H-shaped goals, a small and a "
               "large rectangle in front of them, and lines at 13, 20, 45 and 65 metres from the end line, with a "
               "halfway line across the middle.", "".join(b), pad=60)
    return svg, ("A full-size pitch is 130–145 m long and 80–90 m wide, the same as for Gaelic football. Lines cross it "
                 "at 13, 20, 45 and 65 m from each end line. Over the bar between the posts is a point; under it, into "
                 "the net, a goal worth three points.")


def floorball():
    # 40 m x 20 m, boards with rounded corners. Scale 24 px per metre.
    s = 24
    L, W = 40 * s, 20 * s
    b = [_rect(0, 0, L, W, fill="#2f5fa8", stroke=LINE, sw=8, rx=3 * s)]
    b += [_line(L / 2, 0, L / 2, W, w=3), '<circle cx="%g" cy="%g" r="6" fill="%s"/>' % (L / 2, W / 2, LINE)]
    cy = W / 2
    for gx, sign in ((3.5 * s, 1), (L - 3.5 * s, -1)):
        x0 = gx - sign * 0.65 * s
        # The goalkeeper area: 4 m deep and 5 m wide, starting just behind the goal line.
        b.append(_rect(min(x0, x0 + sign * 4 * s), cy - 2.5 * s, 4 * s, 5 * s, fill="#3a6fc0", stroke=LINE, sw=3))
        b.append(_rect(min(x0, x0 + sign * 1 * s), cy - 1.25 * s, 1 * s, 2.5 * s, stroke=LINE, sw=3))
        b.append(_line(gx, cy - 0.8 * s, gx, cy + 0.8 * s, stroke=ACCENT, w=10))
        for dy in (-1, 1):
            b.append('<circle cx="%g" cy="%g" r="5" fill="%s"/>' % (gx + sign * 3.5 * s, cy + dy * 6 * s, LINE))
    b += [_t(L / 2, W + 34, "40 m", 24, MUTED), _t(-30, W / 2, "20 m", 24, MUTED, rotate=-90),
          _t(3.5 * s + 4 * s + 8, cy - 3.3 * s, "Goalkeeper area", 20, LABEL, "start"),
          _t(L - 3.5 * s, cy + 3.3 * s, "Goal 160 × 115 cm", 20, ACCENT, "end"),
          _t(L / 2, -22, "Centre line", 22, MUTED)]
    svg = _svg("floorball", L, W + 20, "A floorball rink",
               "A rink 40 metres long and 20 metres wide inside low boards with rounded corners. At each end a goal "
               "stands 3.5 metres from the boards, inside a small goal area and a larger goalkeeper area. A centre "
               "line and face-off dots mark the floor.", "".join(b), pad=60)
    return svg, ("The international rink is 40 × 20 m inside boards about 50 cm high. Each goal (160 × 115 cm) stands "
                 "3.5 m from the end boards, in front of a 4 × 5 m goalkeeper area that outfield players may not enter.")


def netball():
    # 30.5 m x 15.25 m. Scale 30 px per metre.
    s = 30
    L, W = 30.5 * s, 15.25 * s
    b = [_rect(0, 0, L, W, fill="#1f6f78", stroke=LINE)]
    b += [_line(L / 3, 0, L / 3, W), _line(2 * L / 3, 0, 2 * L / 3, W),
          '<circle cx="%g" cy="%g" r="%g" fill="none" stroke="%s" stroke-width="4"/>' % (L / 2, W / 2, 0.45 * s, LINE)]
    r = 4.9 * s
    cy = W / 2
    b.append('<path d="M0 %g A%g %g 0 0 1 0 %g" fill="#26838d" stroke="%s" stroke-width="4"/>' % (cy - r, r, r, cy + r, LINE))
    b.append('<path d="M%g %g A%g %g 0 0 0 %g %g" fill="#26838d" stroke="%s" stroke-width="4"/>' % (L, cy - r, r, r, L, cy + r, LINE))
    b += ['<circle cx="%g" cy="%g" r="9" fill="%s"/>' % (0, cy, ACCENT), '<circle cx="%g" cy="%g" r="9" fill="%s"/>' % (L, cy, ACCENT)]
    b += [_t(L / 6 + 30, 44, "Goal third", 26), _t(L / 2, 44, "Centre third", 26), _t(5 * L / 6 - 30, 44, "Goal third", 26),
          _t(r / 2 + 10, cy + 0, "Goal circle", 20, LABEL), _t(L / 2, cy + 0.45 * s + 26, "Centre circle", 20, MUTED),
          _t(L / 2, W + 34, "30.5 m", 24, MUTED), _t(-26, W / 2, "15.25 m", 24, MUTED, rotate=-90)]
    svg = _svg("netball", L, W + 20, "A netball court",
               "A court 30.5 metres long and 15.25 metres wide, divided into three equal thirds. A small centre circle "
               "sits in the middle; at each end a semicircular goal circle of 4.9 metres radius surrounds the goal post.",
               "".join(b), pad=60)
    return svg, ("The court is 30.5 × 15.25 m, in three equal thirds. Goals can only be scored from inside the goal "
                 "circle (radius 4.9 m), and each of the seven positions may play only in its own areas.")


def sepak_takraw():
    # 13.4 m x 6.1 m. Scale 70 px per metre.
    s = 70
    L, W = 13.4 * s, 6.1 * s
    b = [_rect(0, 0, L, W, fill="#2b5fae", stroke=LINE)]
    mid = L / 2
    b.append(_line(mid, -20, mid, W + 20, stroke=ACCENT, w=8))
    for sign in (-1, 1):
        for y, sweep in ((0, 1 if sign > 0 else 0), (W, 0 if sign > 0 else 1)):
            ex = mid + sign * 0.9 * s
            ey = y + (0.9 * s if y == 0 else -0.9 * s)
            b.append('<path d="M%g %g A%g %g 0 0 %d %g %g" fill="none" stroke="%s" stroke-width="4"/>' % (
                ex, y, 0.9 * s, 0.9 * s, sweep if y == 0 else 1 - sweep, mid, ey, LINE))
        cx = mid + sign * (6.7 - 2.45) * s
        b.append('<circle cx="%g" cy="%g" r="%g" fill="none" stroke="%s" stroke-width="4"/>' % (cx, W / 2, 0.3 * s, TEAL))
    b += [_t(mid, -40, "Net (1.52 m men, 1.42 m women)", 22, ACCENT),
          _t(mid + 4.25 * s, W / 2 + 0.3 * s + 26, "Service circle", 20, TEAL),
          _t(mid - 1.4 * s, 0.9 * s + 18, "Quarter circle", 18, MUTED),
          _t(L / 2, W + 40, "13.4 m", 24, MUTED), _t(-26, W / 2, "6.1 m", 24, MUTED, rotate=-90)]
    svg = _svg("sepak-takraw", L, W + 30, "A sepak takraw court",
               "A court 13.4 metres long and 6.1 metres wide, the size of a badminton doubles court, divided by a net. "
               "Quarter circles mark the net ends of each half, and each half has a small service circle.",
               "".join(b), pad=70)
    return svg, ("A court the size of a badminton doubles court, 13.4 × 6.1 m. The server (tekong) serves with one foot "
                 "in the service circle; the feeders stand in the quarter circles by the net.")


def ulama():
    # The taste: a long, narrow strip of earth, divided by the analco. Not to scale (lengths vary between courts).
    L, W = 1000, 120
    b = [_rect(0, 0, L, W, fill="#9a6b45", stroke=LINE)]
    b += [_line(L / 2, -16, L / 2, W + 16, stroke=ACCENT, w=7)]
    b += [_t(L / 2, -36, "Analco (centre line)", 24, ACCENT),
          _t(L / 4, W / 2, "One side's half", 24), _t(3 * L / 4, W / 2, "The other side's half", 24),
          _t(L / 2, W + 42, "The taste: a long, narrow strip of packed earth", 22, MUTED)]
    # The ancient I-shaped court, for comparison.
    y0 = W + 110
    cw, ch, ew, eh = 560, 120, 200, 260
    x0 = (L - cw) / 2
    b.append('<path d="M%g %g h%g v%g h%g v%g h%g v%g h%g v%g h%g v%g h%g v%g Z" fill="#c9b48a" stroke="%s" stroke-width="4"/>' % (
        x0 - ew / 2 + 60, y0, ew, (eh - ch) / 2, cw - 120, -(eh - ch) / 2, ew, eh, -ew, -(eh - ch) / 2, -(cw - 120),
        (eh - ch) / 2, -ew, -eh, LINE))
    b += [_rect(x0 + 60 + ew / 2 - 20, y0 + (eh - ch) / 2 - 18, cw - 120 - ew + 40 + 40, 18, fill="#8a7a60", stroke="none"),
          _rect(x0 + 60 + ew / 2 - 20, y0 + (eh + ch) / 2, cw - 120 - ew + 40 + 40, 18, fill="#8a7a60", stroke="none"),
          '<circle cx="%g" cy="%g" r="13" fill="none" stroke="%s" stroke-width="6"/>' % (L / 2, y0 + (eh - ch) / 2 - 9, ACCENT),
          '<circle cx="%g" cy="%g" r="13" fill="none" stroke="%s" stroke-width="6"/>' % (L / 2, y0 + (eh + ch) / 2 + 9, ACCENT),
          _t(L / 2, y0 + eh / 2, "Playing alley", 22, "#3a2a1a"),
          _t(L / 2, y0 + eh + 34, "An ancient I-shaped court: sloping walls; stone rings on some later courts", 22, MUTED)]
    svg = _svg("ulama", L, y0 + eh + 50, "An ulama court and an ancient ballcourt",
               "Above: the taste, the long narrow earth court of modern ulama, divided across the middle by the "
               "analco line. Below: the I-shaped plan of an ancient Mesoamerican stone ballcourt, a playing alley "
               "between two sloping walls, with end zones; some later courts had a stone ring set high on each wall.",
               "".join(b), pad=50)
    return svg, ("Not to scale. Above: the taste of modern ulama de cadera, a long, narrow strip divided by the analco; "
                 "its length varies from place to place. Below: the I-shaped plan of many ancient stone ballcourts. "
                 "Stone rings appear only on some later courts.")


DIAGRAMS = {"kabaddi": kabaddi, "kho-kho": kho_kho, "hurling": hurling, "floorball": floorball, "netball": netball,
            "sepak-takraw": sepak_takraw, "ulama": ulama}
