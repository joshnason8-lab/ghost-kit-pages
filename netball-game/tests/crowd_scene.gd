extends Node3D
## A venue as a match builds it, without its crowd: the crowd audit draws its people in it (game/crowd_venues.gd,
## tools/wsg/crowd_audit.gd). At the audit's level (its third argument: 1 Medium, 2 High), or Low.

@export var venue := "arena"
@export var low := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var keep := int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_LOW if low else clampi(int(args[2]) if args.size() > 2 else 2, 1, 2)
	var a := Arena.new(venue)
	a.crowd_off = true
	add_child(a)
	Game.settings.graphics = keep
