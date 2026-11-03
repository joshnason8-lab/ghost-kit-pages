class_name WsgAssetLint
extends RefCounted
## The asset lint (owner-approved item 9): what is wrong with an asset, found when it is imported (the editor plugin,
## addons/wsg_foundation/plugin.cfg) and in CI (tools/wsg/asset_lint.gd) - before a release gate or a player finds it.
## Each check returns issues: {"check", "path", "what", "fail": bool (false: a warning)}.
##   textures   an imported texture over 2 MB that is not GPU-compressed (the release gate's rule, at import); a 3D
##              texture of 512 px or more without mipmaps (shimmers far off).
##   lods       an imported model with LODs off (meshes/generate_lods=false) and over LOD_TRIS triangles.
##   licensed   no raw FBX, nothing under addons/wsg_foundation/data/ and nothing named mobility/actorcore/mixamo
##              committed (the licence: licensed data lives only in the private assets repo and ships only inside APKs);
##              the data folder git-ignored.
##   toe_up     a body whose model rests toe-up (WsgFootFlat.sole_tilt at or over MIN_TILT) without WsgFootFlat.
##   props      a prop-shaped mesh in a venue (on the ground, 0.3-3.5 m tall, under 12 m across) that no solid prop
##              covers and that is not opted out (wsg_solid false, with a reason).

const TEXTURE_MAX := 2 * 1024 * 1024
const MIP_MIN := 512
const LOD_TRIS := 5000
const FIRST_COMPRESSED := 17


static func issue(check: String, path: String, what: String, fail := true) -> Dictionary:
	return {"check": check, "path": path, "what": what, "fail": fail}


## Every .import under DIR (recursive), as [path of the .import, ConfigFile].
static func imports(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".import"):
			var cf := ConfigFile.new()
			if cf.load(dir.path_join(f)) == OK:
				out.append([dir.path_join(f), cf])
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		out.append_array(imports(dir.path_join(sub)))
	return out


## textures: one texture's .import (CF; its own path IMP).
static func texture(imp: String, cf: ConfigFile) -> Array:
	var out := []
	if str(cf.get_value("remap", "importer", "")) != "texture":
		return out
	var src := imp.trim_suffix(".import")
	var mode := int(cf.get_value("params", "compress/mode", 0))
	for key in cf.get_section_keys("remap"):
		if not String(key).begins_with("path"):
			continue
		var ctex := str(cf.get_value("remap", key))
		var f := FileAccess.open(ctex, FileAccess.READ)
		if f == null:
			continue
		var head := f.get_buffer(64)
		var size := f.get_length()
		f.close()
		if head.size() < 52 or head.slice(0, 4).get_string_from_ascii() != "GST2":
			continue
		var w := head.decode_u32(8)
		var h := head.decode_u32(12)
		var df := head.decode_u32(36)
		var fmt := head.decode_u32(48)
		var compressed := (df == 0 and fmt >= FIRST_COMPRESSED) or df == 3
		if not compressed and size > TEXTURE_MAX:
			out.append(issue("textures", src, "%dx%d, %.1f MB and not GPU-compressed (compress/mode %d): set VRAM Compressed (the release gate fails it)" % [w, h, size / 1048576.0, mode]))
		if compressed and maxi(w, h) >= MIP_MIN and not bool(cf.get_value("params", "mipmaps/generate", false)):
			out.append(issue("textures", src, "%dx%d on models without mipmaps: it shimmers far off (mipmaps/generate)" % [w, h], false))
	return out


## lods: one model's .import.
static func lods(imp: String, cf: ConfigFile) -> Array:
	var out := []
	if str(cf.get_value("remap", "importer", "")) != "scene":
		return out
	if bool(cf.get_value("params", "meshes/generate_lods", true)):
		return out
	var src := imp.trim_suffix(".import")
	var ps: Variant = load(src) if ResourceLoader.exists(src) else null
	if not ps is PackedScene:
		return out
	var n: Node = (ps as PackedScene).instantiate()
	var tris := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh:
			tris += (mi as MeshInstance3D).mesh.get_faces().size() / 3
	n.free()
	if tris > LOD_TRIS:
		out.append(issue("lods", src, "%d triangles with LODs off (meshes/generate_lods=false): far off it costs what it does near" % tris))
	return out


## licensed: the repository's tracked files (git ls-files under the project; REPO_FILES given by a test).
static func licensed(repo_files: Array, ignored_data: bool) -> Array:
	var out := []
	for p: String in repo_files:
		var l := p.to_lower()
		if l.ends_with(".fbx"):
			out.append(issue("licensed", p, "a raw FBX committed (never commit FBX or anything taken from them: licensed data lives only in the private assets repo)"))
		elif l.contains("wsg_foundation/data/"):
			out.append(issue("licensed", p, "licensed data committed (addons/wsg_foundation/data/ is fetched by CI, never committed)"))
		elif (l.contains("mobility") or l.contains("actorcore") or l.contains("mixamo")) and (l.ends_with(".res") or l.ends_with(".tres") or l.ends_with(".anim") or l.ends_with(".exr") or l.ends_with(".png")):
			out.append(issue("licensed", p, "looks like licensed motion or a texture baked from it (mobility/actorcore/mixamo): keep it out of the repo"))
	if not ignored_data:
		out.append(issue("licensed", "addons/wsg_foundation/data/", "not git-ignored: one `git add .` would publish the licensed data"))
	return out


## toe_up: a body as the game builds it.
## (TILT: the model's measured tilt, if already measured; -1: measure it - WsgFootFlat.sole_tilt.)
static func toe_up(body: WsgBody, who := "the player", tilt := -1.0) -> Array:
	if tilt < 0.0:
		tilt = WsgFootFlat.sole_tilt(body)
	if tilt < WsgFootFlat.MIN_TILT:
		return []
	for c in body.skeleton.get_children():
		if c is WsgFootFlat:
			return []
	return [issue("toe_up", who, "the model rests %.1f degrees toe-up and its body has no WsgFootFlat (WsgFootFlat.attach(body) last): toes off the ground in every move" % tilt)]


## props: a venue's meshes (under ROOT) against its solid props.
static func props(root: Node, solid: WsgSolidProps, venue := "venue") -> Array:
	var out := []
	var skip := ["ground", "floor", "pitch", "court", "grass", "line", "sky", "crowd", "ball", "net"]
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() or m.skin != null:
			continue
		if _under(m, ["WsgBody", "WsgCrowd3D", "WsgCrowdCards", "WsgOfficial"]):
			continue
		var lname := String(m.name).to_lower()
		if skip.any(func(s: String) -> bool: return lname.contains(s)):
			continue
		if WsgSolidProps._opted_out(m, root) != "":
			continue
		var ab := m.global_transform * m.mesh.get_aabb()
		var tall := ab.size.y
		var across := maxf(ab.size.x, ab.size.z)
		if ab.position.y > 0.3 or tall < 0.3 or tall > 3.5 or across > 12.0:
			continue
		var c := ab.get_center()
		var pen := solid.penetration(Vector3(c.x, ab.position.y, c.z), 0.05, minf(tall, 1.8))
		if float(pen[0]) <= 0.0:
			out.append(issue("props", "%s: %s" % [venue, m.name], "a %.1f m tall, %.1f m across mesh on the ground that no solid prop covers: register it (WsgSolidProps.register/add) or opt it out with wsg_solid false and a reason" % [tall, across]))
	return out


static func _under(n: Node, classes: Array) -> bool:
	var at := n.get_parent()
	while at != null:
		for c in classes:
			if at.is_class(c) or (at.get_script() and (at.get_script() as Script).get_global_name() == c):
				return true
		at = at.get_parent()
	return false


## Allowed issues: lines "<glob>\t<the owner's note>" (res://asset_lint_allow.txt).
static func allow_rules(path := "res://asset_lint_allow.txt") -> Array:
	var out := []
	if FileAccess.file_exists(path):
		for line in FileAccess.get_file_as_string(path).split("\n", false):
			if line.begins_with("#") or not line.contains("\t"):
				continue
			out.append([line.get_slice("\t", 0).strip_edges(), line.get_slice("\t", 1).strip_edges()])
	return out


static func excused(i: Dictionary, rules: Array) -> String:
	for r in rules:
		if String(i.path).match(r[0]) or String(i.path).trim_prefix("res://").match(r[0]):
			return r[1]
	return ""
