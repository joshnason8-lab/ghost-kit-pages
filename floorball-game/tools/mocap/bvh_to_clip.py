#!/usr/bin/env python3
"""CMU motion capture (BVH) -> one looping stride cycle for the game's skeleton (assets/mocap/<name>.json).

    python3 -I tools/mocap/bvh_to_clip.py <clip.bvh> <name> [cycle] [--report]

Reads a CMU BVH (31 joints, 120 fps, Y up, the actor facing +Z with his left at +X: the game's axes), finds the left
foot's strikes, takes one cycle (left strike to left strike; `cycle` picks which, default the middle one), and turns it
onto the game's bones (game/body.gd BONES): each CMU joint's world rotation, turned once so that the CMU bone's rest
direction becomes the game bone's (limbs down, trunk up), then made local to the game's parent. Then:

- heading: the cycle is turned so that its travel runs along +Z, and the root's travel taken out: the clip moves on
  the spot and the game's movement (game/player.gd step()) stays the only thing that moves a player;
- foot locks: where a foot is on the floor (slow in the world, low), its ankle is held at one point of the floor by
  two-bone IK on the game's leg, so the foot does not slide when the game advances the cycle by the ground covered;
- the cycle's end is blended into its start so it loops, and it is resampled to 30 frames a second;
- what is stored: per frame the hips' offset (side, up, forward, m) and a quaternion per bone, rounded to 3
  decimals, plus the stride (m of ground covered by one cycle at the game's size) and the speed it was captured at.

The BVH files themselves are not kept in the repository (docs/MOCAP.md has where they come from).
"""
import json
import math
import sys

import numpy as np

FPS = 30
# The game's skeleton (game/body.gd BONES): name, parent, offset at rest.
GAME = [
	("hips", None, (0, 0.95, 0)),
	("spine", "hips", (0, 0.12, 0)),
	("chest", "spine", (0, 0.2, 0)),
	("neck", "chest", (0, 0.21, 0)),
	("head", "neck", (0, 0.07, 0)),
	("upperarm_l", "chest", (0.2, 0.16, 0)),
	("forearm_l", "upperarm_l", (0, -0.28, 0)),
	("hand_l", "forearm_l", (0, -0.25, 0)),
	("upperarm_r", "chest", (-0.2, 0.16, 0)),
	("forearm_r", "upperarm_r", (0, -0.28, 0)),
	("hand_r", "forearm_r", (0, -0.25, 0)),
	("thigh_l", "hips", (0.1, -0.05, 0)),
	("shin_l", "thigh_l", (0, -0.44, 0)),
	("foot_l", "shin_l", (0, -0.42, 0)),
	("thigh_r", "hips", (-0.1, -0.05, 0)),
	("shin_r", "thigh_r", (0, -0.44, 0)),
	("foot_r", "shin_r", (0, -0.42, 0)),
]
# game bone: (CMU joint whose rotation turns it, CMU child whose offset is the bone's rest direction or None to keep
# the joint's frame as it is, the game bone's rest direction)
MAP = {
	"hips": ("Hips", None, None),
	"spine": ("LowerBack", None, None),
	"chest": ("Spine1", None, None),
	"neck": ("Neck1", None, None),
	"head": ("Head", None, None),
	"upperarm_l": ("LeftArm", "LeftForeArm", (0, -1, 0)),
	"forearm_l": ("LeftForeArm", "LeftHand", (0, -1, 0)),
	"hand_l": ("LeftHand", "LeftHandIndex1", (0, -1, 0)),
	"upperarm_r": ("RightArm", "RightForeArm", (0, -1, 0)),
	"forearm_r": ("RightForeArm", "RightHand", (0, -1, 0)),
	"hand_r": ("RightHand", "RightHandIndex1", (0, -1, 0)),
	"thigh_l": ("LeftUpLeg", "LeftLeg", (0, -1, 0)),
	"shin_l": ("LeftLeg", "LeftFoot", (0, -1, 0)),
	"foot_l": ("LeftFoot", "LeftToeBase", (0, -0.25, 1)),
	"thigh_r": ("RightUpLeg", "RightLeg", (0, -1, 0)),
	"shin_r": ("RightLeg", "RightFoot", (0, -1, 0)),
	"foot_r": ("RightFoot", "RightToeBase", (0, -0.25, 1)),
}
GAME_LEG = 0.86   # thigh + shin (m)


# ---------------------------------------------------------------- rotations

def rx(a):
	c, s = math.cos(a), math.sin(a)
	return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(a):
	c, s = math.cos(a), math.sin(a)
	return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(a):
	c, s = math.cos(a), math.sin(a)
	return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def arc(a, b):
	"""The shortest rotation taking direction a to direction b."""
	a = np.asarray(a, float) / np.linalg.norm(a)
	b = np.asarray(b, float) / np.linalg.norm(b)
	v = np.cross(a, b)
	c = float(np.dot(a, b))
	if np.linalg.norm(v) < 1e-9:
		return np.eye(3) if c > 0 else rx(math.pi)
	k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
	return np.eye(3) + k + k @ k * (1.0 / (1.0 + c))


def to_quat(m):
	"""Rotation matrix -> (x, y, z, w)."""
	t = m[0, 0] + m[1, 1] + m[2, 2]
	if t > 0:
		s = math.sqrt(t + 1.0) * 2
		q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s]
	elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
		s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
		q = [0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
	elif m[1, 1] > m[2, 2]:
		s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
		q = [(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
	else:
		s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
		q = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s]
	q = np.array(q)
	return q / np.linalg.norm(q)


def from_quat(q):
	x, y, z, w = q
	return np.array([
		[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
		[2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
		[2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def slerp(a, b, t):
	if np.dot(a, b) < 0:
		b = -b
	d = min(1.0, float(np.dot(a, b)))
	if d > 0.9995:
		q = a + (b - a) * t
		return q / np.linalg.norm(q)
	th = math.acos(d)
	return (a * math.sin((1 - t) * th) + b * math.sin(t * th)) / math.sin(th)


# ---------------------------------------------------------------- BVH

def read_bvh(path):
	tok = open(path).read().split()
	joints = []   # name, parent index, offset, channels
	stack = []
	i = 0
	while tok[i] != "MOTION":
		t = tok[i]
		if t in ("ROOT", "JOINT"):
			joints.append([tok[i + 1], stack[-1] if stack else -1, None, []])
			i += 2
		elif t == "End":
			joints.append(["_end", stack[-1], None, []])
			i += 2
		elif t == "{":
			stack.append(len(joints) - 1)
			i += 1
		elif t == "}":
			stack.pop()
			i += 1
		elif t == "OFFSET":
			joints[stack[-1]][2] = np.array([float(x) for x in tok[i + 1:i + 4]])
			i += 4
		elif t == "CHANNELS":
			n = int(tok[i + 1])
			joints[stack[-1]][3] = tok[i + 2:i + 2 + n]
			i += 2 + n
		else:
			i += 1
	frames = int(tok[i + 2])
	dt = float(tok[i + 5])
	nch = sum(len(j[3]) for j in joints)
	data = np.array([float(x) for x in tok[i + 6:i + 6 + frames * nch]]).reshape(frames, nch)
	return joints, data, dt


def fk(joints, row):
	"""World rotation and position of every joint for one frame."""
	R, P = [], []
	c = 0
	for name, parent, off, ch in joints:
		loc = np.eye(3)
		pos = off.copy()
		for k in ch:
			v = row[c]
			c += 1
			if k == "Xposition":
				pos[0] = v
			elif k == "Yposition":
				pos[1] = v
			elif k == "Zposition":
				pos[2] = v
			elif k == "Xrotation":
				loc = loc @ rx(math.radians(v))
			elif k == "Yrotation":
				loc = loc @ ry(math.radians(v))
			elif k == "Zrotation":
				loc = loc @ rz(math.radians(v))
		if parent < 0:
			R.append(loc)
			P.append(pos)
		else:
			R.append(R[parent] @ loc)
			P.append(P[parent] + R[parent] @ off)
	return R, P


# ---------------------------------------------------------------- the game's skeleton

def game_fk(local, hips_off):
	"""World rotation and position of the game's bones from local rotations (3x3) and the hips' offset."""
	R, P = {}, {}
	for name, parent, off in GAME:
		off = np.array(off, float)
		if parent is None:
			R[name] = local[name]
			P[name] = off + hips_off
		else:
			R[name] = R[parent] @ local[name]
			P[name] = P[parent] + R[parent] @ off
	return R, P


def leg_ik(local, hips_off, side, target):
	"""Turns thigh and shin so the ankle reaches target (two-bone, the knee kept in the plane it bends in)."""
	R, P = game_fk(local, hips_off)
	hip, knee, ankle = P["thigh_" + side], P["shin_" + side], P["foot_" + side]
	a, b = 0.44, 0.42
	want = target - hip
	d = min(np.linalg.norm(want), a + b - 1e-4)
	# The knee's angle for that distance.
	cos_k = (a * a + b * b - d * d) / (2 * a * b)
	k_ang = math.acos(max(-1.0, min(1.0, cos_k)))
	cur_k = math.acos(max(-1.0, min(1.0, np.dot(hip - knee, ankle - knee) / (a * b))))
	# Bend the knee about the shin's own X (its hinge) by the difference.
	turn = cur_k - k_ang   # >0 straightens
	local["shin_" + side] = local["shin_" + side] @ _axis_angle(np.array([1.0, 0, 0]), turn)
	R, P = game_fk(local, hips_off)
	cur = P["foot_" + side] - P["thigh_" + side]
	# Then swing the whole leg from the hip onto the target.
	w = arc(cur, want)
	parent_w = R["hips"]
	local["thigh_" + side] = parent_w.T @ w @ parent_w @ local["thigh_" + side]
	R, P = game_fk(local, hips_off)
	return float(np.linalg.norm(P["foot_" + side] - target))


def _axis_angle(axis, ang):
	axis = axis / np.linalg.norm(axis)
	k = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
	return np.eye(3) + math.sin(ang) * k + (1 - math.cos(ang)) * (k @ k)


# ---------------------------------------------------------------- the clip

def convert(path, name, which=None, report=False):
	joints, data, dt = read_bvh(path)
	idx = {j[0]: n for n, j in enumerate(joints)}
	# Units: the CMU leg (thigh + shin) against the game's.
	cmu_leg = np.linalg.norm(joints[idx["LeftLeg"]][2]) + np.linalg.norm(joints[idx["LeftFoot"]][2])
	scale = GAME_LEG / cmu_leg
	frames = [fk(joints, row) for row in data]
	n = len(frames)
	# Left foot strikes: the left ankle at its farthest ahead of the hips (once a cycle, walking or running).
	ank = np.array([f[1][idx["LeftFoot"]] for f in frames])
	root = np.array([f[1][idx["Hips"]] for f in frames])
	way = root[-1] - root[0]
	way[1] = 0
	way /= np.linalg.norm(way)
	ahead = (ank - root) @ way
	strikes = []
	win = int(0.2 / dt)
	for i in range(1, n - 1):
		seg = ahead[max(0, i - win):i + win + 1]
		if ahead[i] == seg.max() and ahead[i] > ahead.mean():
			strikes.append(i)
	if len(strikes) < 2:
		raise SystemExit("%s: fewer than two left foot strikes" % path)
	cycles = list(zip(strikes, strikes[1:]))
	c0, c1 = cycles[len(cycles) // 2 if which is None else which]
	period = (c1 - c0) * dt
	travel = root[c1] - root[c0]
	travel[1] = 0
	stride = float(np.linalg.norm(travel)) * scale
	speed = stride / period
	yaw = math.atan2(travel[0], travel[2])
	head = ry(-yaw)   # turns the travel onto +Z
	# Fixed turns from the CMU bones' rest directions to the game's.
	fix = {}
	for g, (j, child, gdir) in MAP.items():
		fix[g] = np.eye(3) if child is None else arc(gdir, joints[idx[child]][2])
	out = []
	m = int(round(period * FPS))
	hips_h = []
	for s in range(m + 1):
		t = s / m
		fi = c0 + t * (c1 - c0)
		a = int(math.floor(fi))
		b = min(a + 1, n - 1)
		u = fi - a
		world = {}
		for g, (j, child, gdir) in MAP.items():
			qa = to_quat(frames[a][0][idx[j]])
			qb = to_quat(frames[b][0][idx[j]])
			world[g] = head @ from_quat(slerp(qa, qb, u)) @ fix[g]
		local = {}
		for g, parent, off in GAME:
			local[g] = world[g] if parent is None else world[parent].T @ world[g]
		rp = root[a] * (1 - u) + root[b] * u
		lin = root[c0] + travel * t
		rel = head @ (rp - lin) * scale
		out.append([local, rel])
		hips_h.append(rel[1])
	# The loop: the last frame's rotations and offset are spread back over the cycle so that it ends where it began;
	# then the last frame (the first again) goes and the cycle is circular.
	first, last = out[0], out[-1]
	for g, parent, off in GAME:
		d = to_quat(last[0][g].T @ first[0][g])
		for s in range(len(out)):
			t = s / (len(out) - 1)
			out[s][0][g] = out[s][0][g] @ from_quat(slerp(np.array([0, 0, 0, 1.0]), d, t))
	dpos = first[1] - last[1]
	for s in range(len(out)):
		out[s][1] = out[s][1] + dpos * (s / (len(out) - 1))
	out = out[:-1]
	# The hips' height: the CMU root's rise and fall, placed so the feet meet the floor at their lowest.
	FLOOR = 0.04   # the ankle's height standing (game/body.gd)
	mean_h = float(np.mean([rel[1] for local, rel in out]))
	lowest = []
	for local, rel in out:
		R, P = game_fk(local, np.array([rel[0], rel[1] - mean_h, rel[2]]))
		lowest.append(min(P["foot_l"][1], P["foot_r"][1]))
	lift = FLOOR - float(np.percentile(lowest, 10))
	for s in range(m):
		out[s][1] = np.array([out[s][1][0], out[s][1][1] - mean_h + lift, out[s][1][2]])
	# Foot locks: a foot low and slow in the world (the clip carried along +Z at the cycle's speed) is held at one
	# spot on the floor for as long as it is down.
	vz = stride / m
	contacts = {}
	targets = {}   # frame -> side -> where the ankle goes
	for side in ("l", "r"):
		wpos = []
		for s, (local, rel) in enumerate(out):
			R, P = game_fk(local, rel)
			w = P["foot_" + side].copy()
			w[2] += vz * s
			wpos.append(w)
		wpos = np.array(wpos)
		ahead = lambda s: wpos[s % m] + np.array([0, 0, stride * (s // m)])
		spd = np.array([np.linalg.norm((ahead(s + 1) - ahead(s - 1 + m) + np.array([0, 0, stride]))[[0, 2]]) * FPS / 2
			for s in range(m)])
		on = (spd < 0.75 * speed) & (wpos[:, 1] < wpos[:, 1].min() + 0.06)
		if on.all():
			raise SystemExit("%s: the %s foot never leaves the floor" % (path, side))
		# Runs of contact, round the cycle: start from a frame the foot is up.
		start = int(np.argmin(on))
		runs = []
		k = 0
		while k < m:
			if on[(start + k) % m]:
				e = k
				while e + 1 < m and on[(start + e + 1) % m]:
					e += 1
				runs.append((start + k, start + e))
				k = e + 1
			else:
				k += 1
		for k0, k1 in runs:
			if k1 - k0 < 1:
				continue
			spot = np.mean([ahead(k) for k in range(k0, k1 + 1)], axis=0)
			for k in range(k0, k1 + 1):
				target = spot - np.array([0, 0, vz * k])
				target[1] = FLOOR + (wpos[k % m][1] - wpos[:, 1].min())   # down on the floor, the heel free to rise
				targets.setdefault(k % m, {})[side] = target
		contacts[side] = [[k0 % m, k1 % m] for k0, k1 in runs if k1 > k0]
		if report:
			print("  %s contact frames: %s, lowest %.3f m" % (side, contacts[side], wpos[:, 1].min()))
	# Where a leg cannot reach its spot (straight at toe-off), the hips come down that much, eased over the frames
	# around; then each foot down is put on its spot.
	reach = 0.86 * 0.995
	need = np.zeros(m)
	for s, t in targets.items():
		local, rel = out[s]
		R, P = game_fk(local, rel)
		for side, target in t.items():
			d = target - P["thigh_" + side]
			h2 = d[0] ** 2 + d[2] ** 2
			if h2 < reach * reach:
				need[s] = max(need[s], -d[1] - math.sqrt(reach * reach - h2))
			else:
				need[s] = max(need[s], -d[1])
	need = np.array([max(need[(s + i) % m] for i in range(-2, 3)) for s in range(m)])
	need = np.array([np.mean([need[(s + i) % m] for i in range(-2, 3)]) for s in range(m)])
	err = 0.0
	for s in range(m):
		out[s][1] = out[s][1] - np.array([0, need[s], 0])
	for s, t in targets.items():
		local, rel = out[s]
		for side, target in t.items():
			err = max(err, leg_ik(local, rel, side, target))
	if report:
		print("  hips lowered up to %.3f m for the feet to reach; IK miss %.3f m" % (need.max(), err))
	# How far forward the captured trunk leans on average (hips, spine and chest, degrees): the game bends its players
	# forward over the stick only by what is missing.
	def pitch(r):
		up = r @ np.array([0, 1.0, 0])
		return math.degrees(math.atan2(up[2], up[1]))
	lean = float(np.mean([pitch(lo["hips"]) + pitch(lo["spine"]) + pitch(lo["chest"]) for lo, rel in out]))
	clip = {
		"name": name,
		"source": "CMU %s" % path.rsplit("/", 1)[-1].split(".")[0],
		"fps": FPS,
		"stride": round(stride, 3),
		"speed": round(speed, 3),
		"lean": round(lean, 1),
		"bones": [g for g, p, o in GAME],
		"contacts": contacts,
		"frames": [],
	}
	for local, rel in out:
		f = [round(float(x), 3) for x in rel]
		for g, parent, off in GAME:
			q = to_quat(local[g])
			if q[3] < 0:
				q = -q
			f += [round(float(x), 3) for x in q]
		clip["frames"].append(f)
	if report:
		print("%s: %s, %d frames of %.0f fps, cycle %d (of %d) %.2f s, stride %.2f m, %.2f m/s, scale %.4f" % (
			name, path, n, 1 / dt, cycles.index((c0, c1)), len(cycles), period, stride, speed, scale))
	return clip


if __name__ == "__main__":
	args = [a for a in sys.argv[1:] if not a.startswith("--")]
	which = int(args[2]) if len(args) > 2 else None
	clip = convert(args[0], args[1], which, "--report" in sys.argv)
	out = "assets/mocap/%s.json" % args[1]
	with open(out, "w") as f:
		json.dump(clip, f, separators=(",", ":"))
	print("wrote", out)
