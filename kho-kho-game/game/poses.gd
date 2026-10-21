class_name Poses
extends RefCounted
## Key poses for ToonBody (bone -> degrees; "hips_y" lowers the body, m; "hips_fwd" moves it forward, m) and the run.
## Kho kho's own: the seated chaser on his toes in his square, the rise on a kho, the kho itself (a palm on the back),
## the sky dive and the pole dive, lying after a dive, and the umpires' whistle and signals.

const STAND := {
	"hips_y": -0.02,
	"spine": Vector3(4, 0, 0), "chest": Vector3(2, 0, 0), "head": Vector3(-4, 0, 0),
	"upperarm_l": Vector3(-4, 0, 8), "forearm_l": Vector3(-14, 0, 0),
	"upperarm_r": Vector3(-4, 0, -8), "forearm_r": Vector3(-14, 0, 0),
	"thigh_l": Vector3(-3, 0, 4), "shin_l": Vector3(5, 0, 0), "foot_l": Vector3(-2, 0, -4),
	"thigh_r": Vector3(-3, 0, -4), "shin_r": Vector3(5, 0, 0), "foot_r": Vector3(-2, 0, 4),
}

## The ready crouch of a defender waiting, or an active chaser looking for his man.
const READY := {
	"hips_y": -0.12,
	"spine": Vector3(22, 0, 0), "chest": Vector3(6, 0, 0), "neck": Vector3(-10, 0, 0), "head": Vector3(-14, 0, 0),
	"upperarm_l": Vector3(-22, 0, 22), "forearm_l": Vector3(-50, 0, 0),
	"upperarm_r": Vector3(-22, 0, -22), "forearm_r": Vector3(-50, 0, 0),
	"thigh_l": Vector3(-34, 0, 9), "shin_l": Vector3(52, 0, 0), "foot_l": Vector3(-18, 0, -8),
	"thigh_r": Vector3(-34, 0, -9), "shin_r": Vector3(52, 0, 0), "foot_r": Vector3(-18, 0, 8),
}

## The seated chaser: on his toes in the square, knees up, hands on the knees, looking across at his half.
const SIT := {
	"hips_y": -0.52, "hips_fwd": -0.06,
	"spine": Vector3(28, 0, 0), "chest": Vector3(6, 0, 0), "neck": Vector3(-14, 0, 0), "head": Vector3(-20, 0, 0),
	"upperarm_l": Vector3(-42, 0, 14), "forearm_l": Vector3(-38, 0, 0), "hand_l": Vector3(0, 0, 0),
	"upperarm_r": Vector3(-42, 0, -14), "forearm_r": Vector3(-38, 0, 0),
	"thigh_l": Vector3(-96, 0, 14), "shin_l": Vector3(128, 0, 0), "foot_l": Vector3(-56, 0, -6),
	"thigh_r": Vector3(-96, 0, -14), "shin_r": Vector3(128, 0, 0), "foot_r": Vector3(-56, 0, 6),
}

## The kho: bent over the seated chaser's back, the right palm on it.
const KHO := {
	"hips_y": -0.22,
	"spine": Vector3(40, 0, -6), "chest": Vector3(12, 0, 0), "neck": Vector3(-22, 0, 0), "head": Vector3(-18, 0, 0),
	"upperarm_l": Vector3(-10, 0, 40), "forearm_l": Vector3(-40, 0, 0),
	"upperarm_r": Vector3(-62, 0, -10), "forearm_r": Vector3(-12, 0, 0), "hand_r": Vector3(-30, 0, 0),
	"thigh_l": Vector3(-46, 0, 8), "shin_l": Vector3(60, 0, 0), "foot_l": Vector3(-12, 0, -6),
	"thigh_r": Vector3(-6, 0, -8), "shin_r": Vector3(42, 0, 0), "foot_r": Vector3(-8, 0, 6),
}

## The sky dive, flat out through the air with both arms reaching.
const DIVE := {
	"hips": Vector3(78, 0, 0), "hips_y": -0.48, "hips_fwd": 0.25,
	"spine": Vector3(4, 0, 0), "chest": Vector3(0, 0, 0), "neck": Vector3(-40, 0, 0), "head": Vector3(-24, 0, 0),
	"upperarm_l": Vector3(-160, 0, 12), "forearm_l": Vector3(-8, 0, 0),
	"upperarm_r": Vector3(-160, 0, -12), "forearm_r": Vector3(-8, 0, 0),
	"thigh_l": Vector3(12, 0, 6), "shin_l": Vector3(14, 0, 0), "foot_l": Vector3(30, 0, 0),
	"thigh_r": Vector3(18, 0, -6), "shin_r": Vector3(30, 0, 0), "foot_r": Vector3(30, 0, 0),
}

## Down on the ground after a dive.
const LIE := {
	"hips": Vector3(88, 0, 0), "hips_y": -0.80, "hips_fwd": 0.35,
	"spine": Vector3(2, 0, 0), "neck": Vector3(-46, 0, 0), "head": Vector3(-20, 0, 0),
	"upperarm_l": Vector3(-150, 0, 30), "forearm_l": Vector3(-30, 0, 0),
	"upperarm_r": Vector3(-160, 0, -18), "forearm_r": Vector3(-10, 0, 0),
	"thigh_l": Vector3(4, 0, 8), "shin_l": Vector3(20, 0, 0), "foot_l": Vector3(40, 0, 0),
	"thigh_r": Vector3(8, 0, -10), "shin_r": Vector3(10, 0, 0), "foot_r": Vector3(40, 0, 0),
}

## The pole dive: the left hand round the pole, the body swung out past it, the right arm at full stretch.
const POLE_DIVE := {
	"hips": Vector3(44, 0, 0), "hips_y": -0.36, "hips_fwd": 0.12,
	"spine": Vector3(14, 0, 0), "neck": Vector3(-30, 0, 0), "head": Vector3(-18, 0, 0),
	"upperarm_l": Vector3(-70, 0, 46), "forearm_l": Vector3(-40, 0, 0),
	"upperarm_r": Vector3(-150, 0, -16), "forearm_r": Vector3(-6, 0, 0),
	"thigh_l": Vector3(-50, 0, 10), "shin_l": Vector3(70, 0, 0),
	"thigh_r": Vector3(26, 0, -10), "shin_r": Vector3(12, 0, 0), "foot_r": Vector3(30, 0, 0),
}

## An umpire: the whistle at his lips.
const WHISTLE := {
	"hips_y": -0.02, "spine": Vector3(2, 0, 0), "head": Vector3(-6, 0, 0),
	"upperarm_l": Vector3(-4, 0, 8), "forearm_l": Vector3(-14, 0, 0),
	"upperarm_r": Vector3(-52, 0, -26), "forearm_r": Vector3(-128, 0, 0), "hand_r": Vector3(0, 0, 0),
	"thigh_l": Vector3(-3, 0, 4), "shin_l": Vector3(5, 0, 0), "thigh_r": Vector3(-3, 0, -4), "shin_r": Vector3(5, 0, 0),
}

## Out: the right arm straight up, whistle in the left hand.
const SIGNAL_OUT := {
	"hips_y": -0.02, "spine": Vector3(0, 0, 0), "head": Vector3(-10, 0, 0),
	"upperarm_l": Vector3(-52, 0, 26), "forearm_l": Vector3(-128, 0, 0),
	"upperarm_r": Vector3(0, 0, -172), "forearm_r": Vector3(0, 0, -4),
	"thigh_l": Vector3(-3, 0, 4), "shin_l": Vector3(5, 0, 0), "thigh_r": Vector3(-3, 0, -4), "shin_r": Vector3(5, 0, 0),
}

## Foul: the right arm out level, pointing the way the active chaser must go to put it right.
const SIGNAL_FOUL := {
	"hips_y": -0.02, "spine": Vector3(0, 0, 0), "head": Vector3(-6, 0, 0),
	"upperarm_l": Vector3(-52, 0, 26), "forearm_l": Vector3(-128, 0, 0),
	"upperarm_r": Vector3(0, 0, -92), "forearm_r": Vector3(0, 0, -2),
	"thigh_l": Vector3(-3, 0, 4), "shin_l": Vector3(5, 0, 0), "thigh_r": Vector3(-3, 0, -4), "shin_r": Vector3(5, 0, 0),
}

## The end of a turn: both arms up, crossed over the head.
const SIGNAL_END := {
	"hips_y": -0.02, "head": Vector3(-10, 0, 0),
	"upperarm_l": Vector3(0, 0, 160), "forearm_l": Vector3(0, 0, 40),
	"upperarm_r": Vector3(0, 0, -160), "forearm_r": Vector3(0, 0, -40),
	"thigh_l": Vector3(-3, 0, 4), "shin_l": Vector3(5, 0, 0), "thigh_r": Vector3(-3, 0, -4), "shin_r": Vector3(5, 0, 0),
}

## A cheer: both arms up and out.
const CHEER := {
	"hips_y": 0.0, "spine": Vector3(-8, 0, 0), "head": Vector3(-16, 0, 0),
	"upperarm_l": Vector3(-10, 0, 150), "forearm_l": Vector3(-20, 0, 0),
	"upperarm_r": Vector3(-10, 0, -150), "forearm_r": Vector3(-20, 0, 0),
	"thigh_l": Vector3(-3, 0, 6), "shin_l": Vector3(5, 0, 0), "thigh_r": Vector3(-3, 0, -6), "shin_r": Vector3(5, 0, 0),
}


static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if k <= 0.0:
		return a
	if k >= 1.0 and a.is_empty():
		return b
	var out := a.duplicate()
	for key in b:
		var va = a.get(key, Vector3.ZERO if b[key] is Vector3 else 0.0)
		var vb = b[key]
		if vb is Vector3:
			out[key] = (va as Vector3).lerp(vb, k)
		else:
			out[key] = lerpf(float(va), float(vb), k)
	for key in a:
		if not b.has(key):
			var va = a[key]
			if va is Vector3:
				out[key] = (va as Vector3).lerp(Vector3.ZERO, k)
			else:
				out[key] = lerpf(float(va), 0.0, k)
	return out


static func mirrored(p: Dictionary) -> Dictionary:
	var out := {}
	for key in p:
		var v = p[key]
		var k: String = key
		if k.ends_with("_l"):
			k = k.left(-2) + "_r"
		elif k.ends_with("_r"):
			k = k.left(-2) + "_l"
		if v is Vector3:
			out[k] = Vector3(v.x, -v.y, -v.z)
		else:
			out[k] = v
	return out


## The running stride at phase ph (radians, one stride each half turn), at k (0-1 of a sprint), side a sidestep (-1..1).
## A kho kho run is low and leaning: the body tips into the chase as it speeds up.
static func run(ph: float, k: float, side := 0.0) -> Dictionary:
	var p := READY.duplicate()
	var s := sin(ph)
	var c := cos(ph)
	var swing := (24.0 + 26.0 * k) * (1.0 - absf(side) * 0.6)
	p.hips_y = -0.08 - 0.06 * k + 0.04 * absf(c) * (0.3 + k)
	p.spine = Vector3(16 + 16 * k, 0, 0)
	p.thigh_l = Vector3(-28 - swing * s, 0, 7 + 16 * side * maxf(0.0, s))
	p.thigh_r = Vector3(-28 + swing * s, 0, -7 + 16 * side * maxf(0.0, -s))
	p.shin_l = Vector3(36 + (28 + 46 * k) * maxf(0.0, -c), 0, 0)
	p.shin_r = Vector3(36 + (28 + 46 * k) * maxf(0.0, c), 0, 0)
	p.upperarm_l = Vector3(-14 + (18 + 30 * k) * s, 0, 16)
	p.upperarm_r = Vector3(-14 - (18 + 30 * k) * s, 0, -16)
	p.forearm_l = Vector3(-70 - 20 * k, 0, 0)
	p.forearm_r = Vector3(-70 - 20 * k, 0, 0)
	return p


## How long one stride is at a speed (m/s): longer the faster he runs (about 1.1 m jogging, 1.9 m flat out).
static func stride(speed: float) -> float:
	return 0.75 + 0.15 * speed
