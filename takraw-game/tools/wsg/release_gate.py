#!/usr/bin/env python3
"""The release gate (owner-approved item 1): what every game's CI checks on its built APK (and Web build) before a
release goes up. Exits 1 if any check fails; writes RELEASE_GATE.md and release_gate.json to --out.

    python3 tools/wsg/release_gate.py --apk build/game-1.2.3.apk --version 1.2.3-beta --out "$RUNNER_TEMP/gate" \
        [--web build/web/index.pck | build/web.zip | build/web/] [--previous last-release.apk] [--published on-the-tag.apk]
        [--allow gate_allow.txt]

The checks:
  signature  every signer's certificate SHA-256 is the owner's key (CERT); apksigner verifies the signatures when the
             Android build-tools have it ($ANDROID_HOME/build-tools/*/apksigner or PATH); without it the certificates
             are read from the APK's v2/v3 signing block and v1 META-INF (read, not verified: said so).
  version    project.binary's application/config/version is --version (or the version in --tag), and the APK's file
             name carries it.
  licensed   the licensed motion (addons/wsg_foundation/data/mobility.res, actorcore.res) is in the APK - and in no
             Web build or downloadable pack (--pack) (MoCap Online, ActorCore and Mixamo-derived data may ship only
             inside an APK/AAB).
  clean      no tests, docs, tools, audit or contact-sheet output, CI or source files in the export (the foundation's
             own test-time scripts are listed as a warning: exclude them unless your game uses them).
  textures   no texture over 2 MB that is not GPU-compressed (a PNG/WebP/raw import is decoded whole into memory).
  files      no non-game files (.blend, .psd, .fbx, .zip, .py, .sh, .log, .orig ...) and no file of over 64 KB twice.
  newer      the APK's versionName and versionCode are both above the release now published on its tag (--published,
             else --previous): the same version republished is never offered as an update (Obtainium).
  size       no cap: the size against --previous, and the 20 files that grew most.
--allow: lines "<glob>\\t<the owner's note>" excusing paths from clean/textures/files (reported with the note).
"""
import argparse
import fnmatch
import glob
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import zipfile

CERT = "6F:23:A9:36:9A:95:60:C5:57:1D:27:04:D2:01:5F:8D:58:3E:B2:65:2E:86:A5:F1:66:2B:E5:D6:C3:69:7B:A3"
LICENSED = ["addons/wsg_foundation/data/mobility.res", "addons/wsg_foundation/data/actorcore.res"]
LICENSED_MARKS = [b"wsg_foundation/data/", b"mobility.res", b"actorcore.res"]
TEXTURE_MAX = 2 * 1024 * 1024
DUP_MIN = 64 * 1024
# Paths (under the export's root) that are not the game.
NOT_GAME_DIRS = re.compile(r"^(tests?|docs|tools|\.github|\.godot/editor|audit[^/]*|sheets?|build|export|screenshots)/")
NOT_GAME_NAME = re.compile(r"(^|/)[^/]*(audit|contact_sheet|_sheet|debug_dump)[^/]*\.(png|jpg|jpeg|json|md|txt|webp)$", re.I)
NOT_GAME_EXT = re.compile(r"\.(md|blend\d?|psd|xcf|kra|fbx|max|ma|mb|zip|7z|rar|tar|gz|py|sh|bat|ps1|yml|yaml|log|orig|bak|tmp|keystore|jks)$", re.I)
# The foundation's test-time scripts (a warning: a game may use WsgNoteChecks.stick_world at run time).
TEST_TIME = re.compile(r"^addons/wsg_foundation/(prop_audit|note_checks|owner_note)\.g[dc]|^addons/wsg_foundation/(sim|world)/")
# Godot's Image.Format: 17 (DXT1) and up are GPU-compressed.
FIRST_COMPRESSED = 17
DATA_FORMATS = {0: "image", 1: "png", 2: "webp", 3: "basis"}


def colon(hexstr):
    h = hexstr.upper().replace(":", "")
    return ":".join(h[i:i + 2] for i in range(0, len(h), 2))


def cert_digests_from_apk(path):
    """The signers' certificate SHA-256s, read from the v3/v2 signing block and the v1 signature (not verified)."""
    out = {}
    data = open(path, "rb").read()
    eocd = data.rfind(b"PK\x05\x06")
    if eocd >= 0:
        cd_off = struct.unpack("<I", data[eocd + 16:eocd + 20])[0]
        if data[cd_off - 16:cd_off] == b"APK Sig Block 42":
            size = struct.unpack("<Q", data[cd_off - 24:cd_off - 16])[0]
            p = cd_off - size - 8 + 8
            end = cd_off - 24
            while p < end:
                ln, ident = struct.unpack("<QI", data[p:p + 12])
                val = data[p + 12:p + 8 + ln]
                if ident in (0x7109871A, 0xF05368C0):
                    name = "v2" if ident == 0x7109871A else "v3"
                    for der in _block_certs(val):
                        out.setdefault(colon(hashlib.sha256(der).hexdigest()), set()).add(name)
                p += 8 + ln
    try:
        from cryptography.hazmat.primitives.serialization import pkcs7, Encoding
        with zipfile.ZipFile(path) as z:
            for n in z.namelist():
                if re.match(r"META-INF/[^/]+\.(RSA|DSA|EC)$", n):
                    for c in pkcs7.load_der_pkcs7_certificates(z.read(n)):
                        out.setdefault(colon(hashlib.sha256(c.public_bytes(Encoding.DER)).hexdigest()), set()).add("v1")
    except ImportError:
        pass
    return out


def _lp(buf, p):
    n = struct.unpack("<I", buf[p:p + 4])[0]
    return buf[p + 4:p + 4 + n], p + 4 + n


def _block_certs(val):
    """Certificates (DER) in a v2/v3 signature scheme block: signers -> signer -> signed data -> certificates."""
    certs = []
    signers, _ = _lp(val, 0)
    p = 0
    while p < len(signers):
        signer, p = _lp(signers, p)
        signed, _ = _lp(signer, 0)
        _digests, q = _lp(signed, 0)
        cert_seq, _ = _lp(signed, q)
        r = 0
        while r < len(cert_seq):
            der, r = _lp(cert_seq, r)
            certs.append(der)
    return certs


def apksigner():
    for d in [os.environ.get("ANDROID_HOME", ""), os.environ.get("ANDROID_SDK_ROOT", "")]:
        if d:
            found = sorted(glob.glob(os.path.join(d, "build-tools", "*", "apksigner")))
            if found:
                return found[-1]
    return shutil.which("apksigner")


def manifest_version(axml):
    """(versionName, versionCode) from an APK's binary AndroidManifest.xml (AXML): the <manifest> element's
    android:versionName (0x0101021c) and android:versionCode (0x0101021b); None for one it lacks."""
    if len(axml) < 8 or struct.unpack("<H", axml[0:2])[0] != 0x0003:
        return None, None
    strings, res_ids = [], []
    p = struct.unpack("<H", axml[2:4])[0]
    while p + 8 <= len(axml):
        ctype, hsize, csize = struct.unpack("<HHI", axml[p:p + 8])
        if csize < 8:
            break
        if ctype == 0x0001:  # string pool
            count, _styles, flags, sstart = struct.unpack("<IIII", axml[p + 8:p + 24])
            utf8 = bool(flags & 0x100)
            offs = struct.unpack("<%dI" % count, axml[p + hsize:p + hsize + 4 * count])
            base = p + sstart
            for o in offs:
                q = base + o
                if utf8:
                    n = axml[q]
                    q += 2 if n & 0x80 else 1
                    n = axml[q]
                    if n & 0x80:
                        n = ((n & 0x7F) << 8) | axml[q + 1]
                        q += 1
                    q += 1
                    strings.append(axml[q:q + n].decode("utf-8", "replace"))
                else:
                    n = struct.unpack("<H", axml[q:q + 2])[0]
                    q += 2
                    if n & 0x8000:
                        n = ((n & 0x7FFF) << 16) | struct.unpack("<H", axml[q:q + 2])[0]
                        q += 2
                    strings.append(axml[q:q + 2 * n].decode("utf-16-le", "replace"))
        elif ctype == 0x0180:  # resource ids of the attribute names
            res_ids = list(struct.unpack("<%dI" % ((csize - hsize) // 4), axml[p + hsize:p + csize]))
        elif ctype == 0x0102:  # start element
            name = struct.unpack("<I", axml[p + 20:p + 24])[0]
            if name < len(strings) and strings[name] == "manifest":
                astart, asize, acount = struct.unpack("<HHH", axml[p + 24:p + 30])
                vname = vcode = None
                for k in range(acount):
                    a = p + 16 + astart + k * asize
                    _ns, aname, raw, _sz, _r, dtype, data = struct.unpack("<IIIHBBI", axml[a:a + 20])
                    rid = res_ids[aname] if aname < len(res_ids) else 0
                    if rid == 0x0101021C or (rid == 0 and aname < len(strings) and strings[aname] == "versionName"):
                        if raw != 0xFFFFFFFF and raw < len(strings):
                            vname = strings[raw]
                        elif dtype == 0x03 and data < len(strings):
                            vname = strings[data]
                    elif rid == 0x0101021B or (rid == 0 and aname < len(strings) and strings[aname] == "versionCode"):
                        if 0x10 <= dtype <= 0x1F:
                            vcode = data
                        elif raw != 0xFFFFFFFF and raw < len(strings) and strings[raw].isdigit():
                            vcode = int(strings[raw])
                return vname, vcode
        p += csize
    return None, None


def version_key(v):
    """A version string as something to compare: its numbers first, then a release above any pre-release of it
    (0.9.8 > 0.9.8-beta), then the pre-release's parts in order (numbers as numbers: beta.10 > beta.9)."""
    m = re.match(r"^\D*?(\d+(?:\.\d+)*)(?:[-+](.*))?$", (v or "").strip())
    if not m:
        return None
    core = tuple(int(x) for x in m.group(1).split("."))
    core = core + (0,) * (4 - len(core))
    pre = m.group(2)
    if not pre:
        return (core, 1, ())
    parts = tuple((0, int(x), "") if x.isdigit() else (1, 0, x) for x in re.split(r"[.\-]", pre) if x)
    return (core, 0, parts)


def project_version(binary):
    """application/config/version from a Godot project.binary (ECFG)."""
    if binary[:4] != b"ECFG":
        return None
    count = struct.unpack("<I", binary[4:8])[0]
    p = 8
    for _ in range(count):
        kl = struct.unpack("<I", binary[p:p + 4])[0]
        key = binary[p + 4:p + 4 + kl].decode("utf-8", "replace")
        p += 4 + kl
        vl = struct.unpack("<I", binary[p:p + 4])[0]
        val = binary[p + 4:p + 4 + vl]
        p += 4 + vl
        if key == "application/config/version":
            vtype = struct.unpack("<I", val[0:4])[0] & 0xFF
            if vtype == 4:  # STRING
                sl = struct.unpack("<I", val[4:8])[0]
                return val[8:8 + sl].decode("utf-8", "replace")
    return None


def ctex_info(head):
    """(width, height, data format, image format, GPU-compressed) from a .ctex's first bytes."""
    if head[:4] != b"GST2" or len(head) < 52:
        return None
    w, h = struct.unpack("<II", head[8:16])
    df = struct.unpack("<I", head[36:40])[0]
    fmt = struct.unpack("<I", head[48:52])[0]
    compressed = (df == 0 and fmt >= FIRST_COMPRESSED) or df == 3
    return w, h, DATA_FORMATS.get(df, str(df)), fmt, compressed


def load_allow(path):
    rules = []
    if path:
        for line in open(path, encoding="utf-8"):
            line = line.rstrip("\n")
            if line.strip() and not line.startswith("#"):
                g, _, note = line.partition("\t")
                if not note.strip():
                    sys.exit("release_gate: %s: '%s' names no owner's note (a tab, then the note)" % (path, g))
                rules.append((g.strip(), note.strip()))
    return rules


def excused(path, rules):
    # (A glob may name the path as it is in the APK, "assets/...", or as it is in the project.)
    for g, note in rules:
        if fnmatch.fnmatch(path, g) or fnmatch.fnmatch("assets/" + path, g):
            return note
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--apk", required=True)
    ap.add_argument("--version", help="the release's version (as project.godot's application/config/version)")
    ap.add_argument("--tag", help="the release tag, if it carries the version (e.g. kabaddi-raid-0.14.6-beta)")
    ap.add_argument("--web", help="the Web build: its .pck, a .zip of it, or its folder")
    ap.add_argument("--previous", help="the previous release's APK (the size diff; and the published one, if no --published)")
    ap.add_argument("--published", help="the APK now published on the release's tag (this one must be a higher version)")
    ap.add_argument("--pack", help="the downloadable High pack (.pck): public, so it must hold no licensed data")
    ap.add_argument("--allow", help="owner-excused paths: '<glob>\\t<the owner's note>' a line")
    ap.add_argument("--cert", default=CERT)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    version = a.version
    if not version and a.tag:
        m = re.search(r"(\d+\.\d+(?:\.\d+)*(?:-[A-Za-z0-9.]+)?)$", a.tag)
        version = m.group(1) if m else None
    rules = load_allow(a.allow)
    res = {"checks": {}, "warnings": [], "excused": []}

    def check(name, fails, lines):
        res["checks"][name] = {"pass": not fails, "fails": fails, "lines": lines}

    z = zipfile.ZipFile(a.apk)
    infos = [i for i in z.infolist() if not i.is_dir()]
    names = {i.filename: i for i in infos}
    root = "assets/" if any(n.startswith("assets/") for n in names) else ""
    game = {n[len(root):]: i for n, i in names.items() if n.startswith(root)} if root else names

    # signature
    want = colon(a.cert)
    fails, lines = [], []
    tool = apksigner()
    if tool:
        r = subprocess.run([tool, "verify", "--print-certs", "--verbose", a.apk], capture_output=True, text=True)
        digs = [colon(d) for d in re.findall(r"certificate SHA-256 digest: ([0-9a-fA-F]+)", r.stdout)]
        lines.append("apksigner %s: %s" % ("verified" if r.returncode == 0 else "FAILED (exit %d)" % r.returncode, ", ".join(sorted(set(digs))) or "no certificates"))
        if r.returncode != 0:
            fails.append("apksigner does not verify the APK: %s" % (r.stderr.strip().splitlines() or ["?"])[-1])
    else:
        found = cert_digests_from_apk(a.apk)
        digs = list(found)
        lines.append("certificates read (no apksigner here: read, not verified): " + "; ".join("%s (%s)" % (d, ", ".join(sorted(s))) for d, s in found.items()))
    if not digs:
        fails.append("no signing certificate found: the APK is unsigned")
    for d in set(digs):
        if d != want:
            fails.append("signed with %s, not the owner's key %s" % (d, want))
    check("signature", fails, lines)

    # version
    fails, lines = [], []
    pb = game.get("project.binary")
    have = project_version(z.read(pb.filename)) if pb else None
    lines.append("project.binary: %s; the release: %s; the file: %s" % (have, version, os.path.basename(a.apk)))
    if not version:
        fails.append("no release version given (--version, or a --tag ending in it)")
    elif have != version:
        fails.append("project.binary says %s, the release is %s" % (have, version))
    elif version not in os.path.basename(a.apk):
        fails.append("the APK's file name does not carry the version %s" % version)
    check("version", fails, lines)

    # newer: above the release published on the tag (Obtainium offers an update only for a higher version; the same
    # 0.9.8 republished with new code never reached an owner who had 0.9.8 - Floorball, 2026-11-03)
    fails, lines = [], []
    mine = manifest_version(z.read("AndroidManifest.xml")) if "AndroidManifest.xml" in names else (None, None)
    lines.append("this APK: versionName %s, versionCode %s" % mine)
    if mine[0] is None or mine[1] is None:
        fails.append("this APK's AndroidManifest.xml has no versionName/versionCode the gate can read")
    pub = a.published or a.previous
    if pub and os.path.exists(pub):
        with zipfile.ZipFile(pub) as pz:
            theirs = manifest_version(pz.read("AndroidManifest.xml")) if "AndroidManifest.xml" in pz.namelist() else (None, None)
        lines.append("published (%s): versionName %s, versionCode %s" % ((os.path.basename(pub),) + theirs))
        if theirs[0] is None or theirs[1] is None:
            fails.append("the published APK's versionName/versionCode cannot be read: nothing to compare against")
        elif mine[0] is not None and mine[1] is not None:
            if mine[1] <= theirs[1]:
                fails.append("versionCode %d is not above the published release's %d" % (mine[1], theirs[1]))
            km, kt = version_key(mine[0]), version_key(theirs[0])
            if km is None or kt is None:
                fails.append("cannot compare versionName %s with the published %s" % (mine[0], theirs[0]))
            elif km <= kt:
                fails.append("versionName %s is not above the published release's %s" % (mine[0], theirs[0]))
    else:
        lines.append("no published APK given (--published or --previous): nothing to compare against")
        res["warnings"].append("newer: no published APK to compare the version against (the first release on its tag?)")
    check("newer", fails, lines)

    # licensed data: in the APK, not on the Web
    fails, lines = [], []
    for f in LICENSED:
        if f in game:
            lines.append("APK holds %s (%.1f MB)" % (f, game[f].file_size / 1048576))
        else:
            fails.append("the APK lacks %s (the licensed motion ships inside the APK)" % f)
    if a.web:
        found = []
        if os.path.isdir(a.web):
            for dp, _, fs in os.walk(a.web):
                for f in fs:
                    p = os.path.join(dp, f)
                    rel = os.path.relpath(p, a.web)
                    if any(m.decode() in rel for m in LICENSED_MARKS):
                        found.append(rel)
                    elif f.endswith(".pck"):
                        blob = open(p, "rb").read()
                        found += ["%s holds %s" % (rel, m.decode()) for m in LICENSED_MARKS if m in blob]
        elif zipfile.is_zipfile(a.web):
            with zipfile.ZipFile(a.web) as w:
                for n in w.namelist():
                    if any(m.decode() in n for m in LICENSED_MARKS):
                        found.append(n)
                    elif n.endswith(".pck"):
                        blob = w.read(n)
                        found += ["%s holds %s" % (n, m.decode()) for m in LICENSED_MARKS if m in blob]
        else:
            blob = open(a.web, "rb").read()
            found += ["%s holds %s" % (os.path.basename(a.web), m.decode()) for m in LICENSED_MARKS if m in blob]
        lines.append("Web build %s: %s" % (a.web, "no licensed data" if not found else "LICENSED DATA: " + ", ".join(found)))
        for f in found:
            fails.append("licensed data in the Web build: %s (never on a public page)" % f)
    else:
        lines.append("no Web build given")
    if a.pack:
        blob = open(a.pack, "rb").read()
        found = [m.decode() for m in LICENSED_MARKS if m in blob]
        lines.append("High pack %s (%.1f MB): %s" % (os.path.basename(a.pack), len(blob) / 1048576, "no licensed data" if not found else "LICENSED DATA: " + ", ".join(found)))
        for f in found:
            fails.append("licensed data in the downloadable pack: %s (a public release asset: only our own, Meshy and CC assets)" % f)
    check("licensed", fails, lines)

    # clean: no tests/docs/tools/audit output in the export
    fails, lines = [], []
    for n in sorted(game):
        why = None
        if NOT_GAME_DIRS.match(n):
            why = "test, doc, tool or audit folder"
        elif NOT_GAME_NAME.search(n):
            why = "audit or contact-sheet output"
        if why:
            note = excused(n, rules)
            if note:
                res["excused"].append("%s: %s" % (n, note))
            else:
                fails.append("%s (%s)" % (n, why))
        elif TEST_TIME.match(n):
            res["warnings"].append("%s: the foundation's test-time code (exclude it from the export unless the game uses it)" % n)
    lines.append("%d files under %s checked" % (len(game), root or "/"))
    check("clean", fails, lines)

    # textures
    fails, lines = [], []
    biggest = []
    for n, i in game.items():
        if n.endswith(".ctex") or n.endswith(".stex"):
            with z.open(i) as f:
                info = ctex_info(f.read(64))
            if not info:
                continue
            w, h, df, fmt, comp = info
            if not comp:
                biggest.append((i.file_size, n, w, h, df))
                if i.file_size > TEXTURE_MAX:
                    note = excused(n, rules)
                    if note:
                        res["excused"].append("%s: %s" % (n, note))
                    else:
                        fails.append("%s: %dx%d %s, %.1f MB, not GPU-compressed (VRAM-compress it: ETC2/ASTC)" % (n, w, h, df, i.file_size / 1048576))
    biggest.sort(reverse=True)
    lines.append("largest textures not GPU-compressed: " + (", ".join("%s %dx%d %s %.1f MB" % (os.path.basename(n).split("-")[0], w, h, df, s / 1048576) for s, n, w, h, df in biggest[:5]) or "none"))
    check("textures", fails, lines)

    # files: non-game types, duplicates
    fails, lines = [], []
    for n in sorted(game):
        if NOT_GAME_EXT.search(n) and not NOT_GAME_DIRS.match(n):
            note = excused(n, rules)
            if note:
                res["excused"].append("%s: %s" % (n, note))
            else:
                fails.append("%s: not a game file" % n)
    by_hash = {}
    for n, i in game.items():
        if i.file_size >= DUP_MIN:
            by_hash.setdefault(hashlib.sha256(z.read(i.filename)).hexdigest(), []).append(n)
    dups = [v for v in by_hash.values() if len(v) > 1]
    for v in dups:
        if all(excused(n, rules) for n in v):
            res["excused"].append("%s: %s" % (" = ".join(v), excused(v[0], rules)))
        else:
            fails.append("the same %.1f MB file twice: %s" % (game[v[0]].file_size / 1048576, " = ".join(sorted(v))))
    lines.append("%d files of %d KB or more compared: %d duplicated" % (sum(len(v) for v in by_hash.values()), DUP_MIN // 1024, len(dups)))
    check("files", fails, lines)

    # size (no cap)
    lines = []
    size = os.path.getsize(a.apk)
    lines.append("APK %.1f MB (%d files)" % (size / 1048576, len(infos)))
    grown = []
    if a.previous and os.path.exists(a.previous):
        psize = os.path.getsize(a.previous)
        lines.append("previous %.1f MB: %+.1f MB" % (psize / 1048576, (size - psize) / 1048576))
        with zipfile.ZipFile(a.previous) as pz:
            prev = {i.filename: i.compress_size for i in pz.infolist() if not i.is_dir()}
        for n, i in names.items():
            d = i.compress_size - prev.get(n, 0)
            if d > 0:
                grown.append((d, n, n not in prev))
        gone = sum(v for n, v in prev.items() if n not in names)
        grown.sort(reverse=True)
        lines.append("top 20 grown: " + ("; ".join("%s %+.2f MB%s" % (n, d / 1048576, " (new)" if new else "") for d, n, new in grown[:20]) or "none"))
        lines.append("removed since: %.2f MB" % (gone / 1048576))
    else:
        lines.append("no previous APK given: no size diff")
    check("size", [], lines)
    res["grown"] = [{"file": n, "bytes": d, "new": new} for d, n, new in grown[:20]]

    failed = [k for k, v in res["checks"].items() if not v["pass"]]
    res["pass"] = not failed
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "release_gate.json"), "w") as f:
        json.dump(res, f, indent=2)
    md = ["# Release gate: %s" % os.path.basename(a.apk), "", "| Check | Result | What broke it |", "|---|---|---|"]
    for k, v in res["checks"].items():
        md.append("| %s | %s | %s |" % (k, "PASS" if v["pass"] else "FAIL", "<br>".join(v["fails"][:10]).replace("|", "/") + (" (+%d more)" % (len(v["fails"]) - 10) if len(v["fails"]) > 10 else "")))
    md.append("")
    for k, v in res["checks"].items():
        md.append("## %s" % k)
        md += ["- %s" % l for l in v["lines"]] + ["- **%s**" % x for x in v["fails"]] + [""]
    if res["warnings"]:
        md += ["## Warnings"] + ["- %s" % w for w in res["warnings"]] + [""]
    if res["excused"]:
        md += ["## Excused by the owner"] + ["- %s" % e for e in res["excused"]] + [""]
    with open(os.path.join(a.out, "RELEASE_GATE.md"), "w") as f:
        f.write("\n".join(md))
    for k, v in res["checks"].items():
        print("%-10s %s %s" % (k, "PASS" if v["pass"] else "FAIL", "; ".join(v["fails"][:3])))
        for l in v["lines"]:
            print("            ", l)
    for w in res["warnings"][:5]:
        print("warning:", w)
    print("RELEASE GATE: %s (%s)" % ("PASS" if not failed else "FAIL: " + ", ".join(failed), os.path.join(a.out, "RELEASE_GATE.md")))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
