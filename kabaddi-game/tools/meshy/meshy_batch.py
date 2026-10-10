#!/usr/bin/env python3
"""Make the assets in docs/MESHY_BRIEF.md with Meshy's API: model, texture, rig, download.

For each asset in tools/meshy/assets.json:
1. Text to 3D preview (realistic, quad topology, the asset's face count, A-pose for people).
2. Refine: PBR texture with the asset's texture prompt.
3. Rig people (not gear) at their height.
4. Download NAME.glb (textured), NAME_rigged.glb and NAME.png (Meshy's thumbnail) to the output folder.

Progress is kept in OUT/manifest.json, so a run that stops resumes where it left off, and a step
that already worked is never paid for twice. Delete an asset's entry there to make it again.

Needs MESHY_API_KEY in the environment, and api.meshy.ai and assets.meshy.ai reachable.
Standard library only.

Usage:
  python3 tools/meshy/meshy_batch.py --dry-run                 # print what would be sent
  python3 tools/meshy/meshy_batch.py --only player_01_raider_haryana
  python3 tools/meshy/meshy_batch.py --kind player             # all players
  python3 tools/meshy/meshy_batch.py                           # everything
"""

import argparse
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

API = "https://api.meshy.ai"
HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
DONE = ("SUCCEEDED",)
FAILED = ("FAILED", "CANCELED", "EXPIRED")


class MeshyError(Exception):
    pass


def call(method, path, body=None, key=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + key)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:500]
        raise MeshyError(f"{method} {path} -> HTTP {e.code}: {detail}") from None


def wait(path, key, label, timeout=1800):
    start = time.time()
    last = None
    while True:
        t = call("GET", path, key=key)
        status = t.get("status")
        progress = t.get("progress")
        if (status, progress) != last:
            print(f"    {label}: {status} {progress if progress is not None else ''}".rstrip(), flush=True)
            last = (status, progress)
        if status in DONE:
            return t
        if status in FAILED:
            msg = (t.get("task_error") or {}).get("message", "")
            raise MeshyError(f"{label} {status}: {msg}")
        if time.time() - start > timeout:
            raise MeshyError(f"{label} still {status} after {timeout} s")
        time.sleep(8)


def download(url, dest):
    tmp = dest.with_suffix(dest.suffix + ".part")
    with urllib.request.urlopen(url, timeout=300) as r, open(tmp, "wb") as f:
        while True:
            chunk = r.read(1 << 16)
            if not chunk:
                break
            f.write(chunk)
    tmp.replace(dest)
    print(f"    saved {dest.relative_to(ROOT)} ({dest.stat().st_size // 1024} KB)", flush=True)


def preview_body(a, model):
    person = a["kind"] != "gear"
    body = {
        "mode": "preview",
        "prompt": a["prompt"],
        "art_style": "realistic",
        "ai_model": model,
        "topology": "quad" if person else "triangle",
        "target_polycount": a["faces"],
        "should_remesh": True,
        "symmetry_mode": "on" if person else "auto",
    }
    if person:
        body["pose_mode"] = "a-pose"
    return body


def refine_body(a, preview_id):
    return {"mode": "refine", "preview_task_id": preview_id, "enable_pbr": True, "texture_prompt": a["texture_prompt"]}


def make(a, out, state, key, model, rig):
    name = a["name"]
    s = state.setdefault(name, {})
    if not s.get("preview_id"):
        s["preview_id"] = call("POST", "/openapi/v2/text-to-3d", preview_body(a, model), key)["result"]
        save_state(out, state)
    wait(f"/openapi/v2/text-to-3d/{s['preview_id']}", key, "model")
    if not s.get("refine_id"):
        s["refine_id"] = call("POST", "/openapi/v2/text-to-3d", refine_body(a, s["preview_id"]), key)["result"]
        save_state(out, state)
    t = wait(f"/openapi/v2/text-to-3d/{s['refine_id']}", key, "texture")
    glb = out / f"{name}.glb"
    if not glb.exists():
        download(t["model_urls"]["glb"], glb)
    if t.get("thumbnail_url") and not (out / f"{name}.png").exists():
        download(t["thumbnail_url"], out / f"{name}.png")
    s["textured"] = glb.name
    save_state(out, state)
    if not rig or a["kind"] == "gear":
        return
    if not s.get("rig_id"):
        body = {"input_task_id": s["refine_id"], "height_meters": a.get("height_m", 1.75)}
        s["rig_id"] = call("POST", "/openapi/v1/rigging", body, key)["result"]
        save_state(out, state)
    t = wait(f"/openapi/v1/rigging/{s['rig_id']}", key, "rig")
    res = t.get("result") or {}
    rigged = out / f"{name}_rigged.glb"
    if not rigged.exists():
        download(res["rigged_character_glb_url"], rigged)
    s["rigged"] = rigged.name
    save_state(out, state)


def save_state(out, state):
    (out / "manifest.json").write_text(json.dumps(state, indent=1))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", nargs="*", help="asset names")
    ap.add_argument("--kind", choices=["player", "gear", "referee", "crowd"])
    ap.add_argument("--out", default=str(ROOT / "assets" / "meshy"))
    ap.add_argument("--model", default="latest", help="Meshy ai_model (default: latest)")
    ap.add_argument("--no-rig", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    assets = json.loads((HERE / "assets.json").read_text())["assets"]
    if a.only:
        assets = [x for x in assets if x["name"] in a.only]
    if a.kind:
        assets = [x for x in assets if x["kind"] == a.kind]
    if not assets:
        sys.exit("no assets match")
    if a.dry_run:
        for x in assets:
            print(x["name"], json.dumps(preview_body(x, a.model)))
            print("  refine", json.dumps(refine_body(x, "<preview id>")))
            if x["kind"] != "gear" and not a.no_rig:
                print("  rig", json.dumps({"input_task_id": "<refine id>", "height_meters": x.get("height_m", 1.75)}))
        return
    key = os.environ.get("MESHY_API_KEY", "")
    if not key:
        sys.exit("MESHY_API_KEY is not set")
    out = pathlib.Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    mf = out / "manifest.json"
    state = json.loads(mf.read_text()) if mf.exists() else {}
    failed = []
    for i, x in enumerate(assets, 1):
        print(f"[{i}/{len(assets)}] {x['name']}", flush=True)
        try:
            make(x, out, state, key, a.model, not a.no_rig)
        except MeshyError as e:
            print("    FAILED:", e, flush=True)
            failed.append(x["name"])
            if "HTTP 400" in str(e) or "HTTP 401" in str(e) or "HTTP 402" in str(e):
                # A bad request, a bad key or no credits: the rest would fail the same way.
                break
    print("done;", len(assets) - len(failed), "ok", ("; failed: " + ", ".join(failed)) if failed else "")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
