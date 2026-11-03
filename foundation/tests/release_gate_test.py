#!/usr/bin/env python3
"""tools/release_gate.py's own test: synthetic APKs (signed with a throwaway key made here; the licensed files are
stand-in bytes, never the real data) - a clean one passes, and each fault a release could have fails its own check.
    python3 tests/release_gate_test.py
"""
import hashlib
import os
import struct
import subprocess
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
GATE = os.path.join(HERE, "..", "tools", "release_gate.py")


def ecfg(version):
    """A Godot project.binary holding application/config/version (and one other key)."""
    def entry(key, s):
        k = key.encode()
        v = s.encode()
        var = struct.pack("<II", 4, len(v)) + v + b"\0" * ((4 - len(v) % 4) % 4)
        return struct.pack("<I", len(k)) + k + struct.pack("<I", len(var)) + var
    body = entry("application/config/name", "Gate Test") + entry("application/config/version", version)
    return b"ECFG" + struct.pack("<I", 2) + body


def ctex(w, h, data_format, image_format, size):
    head = b"GST2" + struct.pack("<IIIIi", 1, w, h, 0, -1) + b"\0" * 12 + struct.pack("<I", data_format)
    head += struct.pack("<HHII", w, h, 0, image_format)
    return head + os.urandom(max(0, size - len(head)))


def build(path, files, key):
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for n, data in files.items():
            z.writestr(n, data)
    subprocess.run(["jarsigner", "-keystore", key, "-storepass", "testpass", "-sigalg", "SHA256withRSA",
        "-digestalg", "SHA-256", path, "gate"], check=True, capture_output=True)


def run(out, *args):
    r = subprocess.run([sys.executable, GATE, "--out", out] + list(args), capture_output=True, text=True)
    failed = [l.split()[0] for l in r.stdout.splitlines() if len(l.split()) > 1 and l.split()[1] == "FAIL"]
    return r.returncode, failed, r.stdout


def main():
    tmp = tempfile.mkdtemp(prefix="gate_test_")
    key = os.path.join(tmp, "k.jks")
    subprocess.run(["keytool", "-genkeypair", "-keystore", key, "-storepass", "testpass", "-keypass", "testpass",
        "-alias", "gate", "-keyalg", "RSA", "-keysize", "2048", "-dname", "CN=gate test", "-validity", "2"],
        check=True, capture_output=True)
    der = subprocess.run(["keytool", "-exportcert", "-keystore", key, "-storepass", "testpass", "-alias", "gate"],
        check=True, capture_output=True).stdout
    cert = hashlib.sha256(der).hexdigest().upper()
    big = os.urandom(200 * 1024)
    base = {
        "AndroidManifest.xml": b"x",
        "assets/project.binary": ecfg("1.2.3-beta"),
        "assets/addons/wsg_foundation/data/mobility.res": b"stand-in, not the data",
        "assets/addons/wsg_foundation/data/actorcore.res": b"stand-in, not the data",
        "assets/game/main.gdc": b"code",
        "assets/fonts/OFL.txt": b"licence",
        "assets/.godot/imported/sky.jpg-1.etc2.ctex": ctex(4096, 2048, 0, 30, 3 * 1024 * 1024),
        "assets/.godot/imported/ui.png-2.ctex": ctex(512, 512, 2, 5, 300 * 1024),
        "assets/music.oggvorbisstr": big,
    }
    cases = [
        ("clean", {}, [], [], "1.2.3-beta"),
        ("wrong key", {}, [], ["--cert", "6F:23:A9:36:9A:95:60:C5:57:1D:27:04:D2:01:5F:8D:58:3E:B2:65:2E:86:A5:F1:66:2B:E5:D6:C3:69:7B:A3"], "signature"),
        ("version", {}, [], ["--version", "1.2.4-beta"], "version"),
        ("no actorcore", {}, ["assets/addons/wsg_foundation/data/actorcore.res"], [], "licensed"),
        ("tests in the export", {"assets/tests/owner_notes/a.gdc": b"t", "assets/audit/contact_sheet.png": b"p"}, [], [], "clean"),
        ("a big raw texture", {"assets/.godot/imported/face.png-3.ctex": ctex(2048, 2048, 1, 5, 3 * 1024 * 1024)}, [], [], "textures"),
        ("a .blend and a duplicate", {"assets/models/player.blend": b"b", "assets/music_copy.oggvorbisstr": big}, [], [], "files"),
    ]
    fails = []
    apk_dir = os.path.join(tmp, "apks")
    os.makedirs(apk_dir)
    for name, add, drop, extra, want in cases:
        files = dict(base)
        files.update(add)
        for d in drop:
            files.pop(d)
        apk = os.path.join(apk_dir, "gate-test-1.2.3-beta.apk")
        if os.path.exists(apk):
            os.remove(apk)
        build(apk, files, key)
        args = ["--apk", apk, "--cert", cert, "--version", "1.2.3-beta"] + extra
        code, failed, out = run(os.path.join(tmp, "out_" + name.replace(" ", "_")), *args)
        expect = [] if want == "1.2.3-beta" else [want]
        ok = failed == expect and (code == 0) == (not expect)
        print("%-26s exit %d, failed %s %s" % (name, code, failed or "nothing", "ok" if ok else "WRONG (want %s)" % (expect or "nothing")))
        if not ok:
            fails.append(name)
            print(out)
    # Owner-excused: the .blend allowed with a note passes (the duplicate is not there).
    files = dict(base)
    files["assets/models/player.blend"] = b"b"
    apk = os.path.join(apk_dir, "gate-test-1.2.3-beta.apk")
    os.remove(apk)
    build(apk, files, key)
    allow = os.path.join(tmp, "allow.txt")
    open(allow, "w").write("assets/models/*.blend\t2026-11-03 the owner: the editable model ships for modders\n")
    code, failed, out = run(os.path.join(tmp, "out_allow"), "--apk", apk, "--cert", cert, "--version", "1.2.3-beta", "--allow", allow)
    print("%-26s exit %d, failed %s %s" % ("owner-excused .blend", code, failed or "nothing", "ok" if code == 0 else "WRONG"))
    if code != 0 or "modders" not in open(os.path.join(tmp, "out_allow", "RELEASE_GATE.md")).read():
        fails.append("allow")
    # The Web: a zip or pack holding licensed data fails; a clean one passes.
    clean = os.path.join(apk_dir, "gate-test-1.2.3-beta.apk")
    for wname, content, bad in [("web_bad.zip", None, True), ("web_bad.pck", b"GDPC..res://addons/wsg_foundation/data/mobility.res..", True), ("web_ok.pck", b"GDPC..res://game/main.tscn..", False)]:
        wp = os.path.join(tmp, wname)
        if content is None:
            with zipfile.ZipFile(wp, "w") as w:
                w.writestr("index.pck", b"GDPC..actorcore.res..")
        else:
            open(wp, "wb").write(content)
        os.remove(clean)
        build(clean, base, key)
        code, failed, out = run(os.path.join(tmp, "out_" + wname), "--apk", clean, "--cert", cert, "--version", "1.2.3-beta", "--web", wp)
        ok = (failed == ["licensed"]) if bad else (code == 0)
        print("%-26s exit %d, failed %s %s" % ("web " + wname, code, failed or "nothing", "ok" if ok else "WRONG"))
        if not ok:
            fails.append(wname)
    # The High pack: one holding licensed data fails; a clean one passes.
    for pname, content, bad in [("pack_bad.pck", b"GDPC..res://addons/wsg_foundation/data/actorcore.res..", True), ("pack_ok.pck", b"GDPC..res://hd/sky_8k.ctex..", False)]:
        pp = os.path.join(tmp, pname)
        open(pp, "wb").write(content)
        code, failed, out = run(os.path.join(tmp, "out_" + pname), "--apk", clean, "--cert", cert, "--version", "1.2.3-beta", "--pack", pp)
        ok = (failed == ["licensed"]) if bad else (code == 0)
        print("%-26s exit %d, failed %s %s" % ("pack " + pname, code, failed or "nothing", "ok" if ok else "WRONG"))
        if not ok:
            fails.append(pname)
    # The size diff against the previous release.
    prev = os.path.join(tmp, "prev.apk")
    files = dict(base)
    files["assets/music.oggvorbisstr"] = os.urandom(50 * 1024)
    build(prev, files, key)
    code, failed, out = run(os.path.join(tmp, "out_size"), "--apk", clean, "--cert", cert, "--version", "1.2.3-beta", "--previous", prev)
    ok = code == 0 and "music.oggvorbisstr" in out and "top 20 grown" in out
    print("%-26s exit %d, %s" % ("size diff", code, "ok: names the grown file" if ok else "WRONG"))
    if not ok:
        fails.append("size")
        print(out)
    print("RELEASE GATE TEST: %s" % ("PASS" if not fails else "FAIL %s" % fails))
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
