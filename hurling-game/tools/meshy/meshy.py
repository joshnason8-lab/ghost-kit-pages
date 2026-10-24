#!/usr/bin/env python3
"""A small client for the Meshy API (api.meshy.ai), as the game's models were made: text to 3D (a preview, then the
textured refine), rigging, and downloads. The key is never in this repository: the session's network proxy adds it.
Each task's id and settings are kept in tools/meshy/tasks.json, so a model can be fetched again or rebuilt.

  python3 tools/meshy/meshy.py preview <name> "<prompt>" [polycount] [t-pose|a-pose|""]
  python3 tools/meshy/meshy.py refine <name> ["<texture prompt>"]
  python3 tools/meshy/meshy.py rig <name> [height_m]
  python3 tools/meshy/meshy.py status <name>
  python3 tools/meshy/meshy.py fetch <name> <stage> <dir>      (stage: preview, refine, rig)
"""
import json
import pathlib
import sys
import time
import urllib.request

API = "https://api.meshy.ai/openapi"
HERE = pathlib.Path(__file__).resolve().parent
TASKS = HERE / "tasks.json"


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())


def load():
    return json.loads(TASKS.read_text()) if TASKS.exists() else {}


def save(t):
    TASKS.write_text(json.dumps(t, indent=1))


def main():
    cmd, name = sys.argv[1], sys.argv[2]
    t = load()
    e = t.setdefault(name, {})
    if cmd == "preview":
        body = {"mode": "preview", "prompt": sys.argv[3], "art_style": "realistic", "should_remesh": True,
                "topology": "triangle", "target_polycount": int(sys.argv[4]) if len(sys.argv) > 4 else 10000}
        if len(sys.argv) > 5 and sys.argv[5]:
            body["pose_mode"] = sys.argv[5]
        e["prompt"] = body
        e["preview"] = call("POST", "/v2/text-to-3d", body)["result"]
    elif cmd == "refine":
        body = {"mode": "refine", "preview_task_id": e["preview"], "enable_pbr": False}
        if len(sys.argv) > 3:
            body["texture_prompt"] = sys.argv[3]
        e["refine"] = call("POST", "/v2/text-to-3d", body)["result"]
    elif cmd == "rig":
        body = {"input_task_id": e["refine"], "height_meters": float(sys.argv[3]) if len(sys.argv) > 3 else 1.8}
        e["rig"] = call("POST", "/v1/rigging", body)["result"]
    elif cmd == "status":
        for stage in ["preview", "refine", "rig"]:
            if stage in e:
                path = ("/v1/rigging/" if stage == "rig" else "/v2/text-to-3d/") + e[stage]
                r = call("GET", path)
                print(name, stage, r.get("status"), r.get("progress"), (r.get("task_error") or {}).get("message", ""))
    elif cmd == "fetch":
        stage, out = sys.argv[3], pathlib.Path(sys.argv[4])
        out.mkdir(parents=True, exist_ok=True)
        path = ("/v1/rigging/" if stage == "rig" else "/v2/text-to-3d/") + e[stage]
        r = call("GET", path)
        (out / f"{name}_{stage}.json").write_text(json.dumps(r, indent=1))
        urls = {}
        if stage == "rig":
            res = r.get("result", {})
            urls["rigged"] = res.get("rigged_character_glb_url")
            for k, v in (res.get("basic_animations") or {}).items():
                if k.endswith("glb_url"):
                    urls[k.replace("_glb_url", "")] = v
        else:
            urls["model"] = (r.get("model_urls") or {}).get("glb")
            urls["thumb"] = r.get("thumbnail_url")
        for k, u in urls.items():
            if u:
                ext = ".png" if k == "thumb" else ".glb"
                urllib.request.urlretrieve(u, out / f"{name}_{stage}_{k}{ext}")
                print("fetched", out / f"{name}_{stage}_{k}{ext}")
    save(t)
    print(name, cmd, {k: v for k, v in e.items() if k != "prompt"})


if __name__ == "__main__":
    main()
