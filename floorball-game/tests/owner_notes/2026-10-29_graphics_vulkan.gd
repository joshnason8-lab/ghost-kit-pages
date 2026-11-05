extends WsgOwnerNote
## The owner, 2026-10-29 (Floorball 0.8.2).

const NOTE := {"id": "2026-10-29-graphics-vulkan", "game": "floorball", "date": "2026-10-29", "version": "0.8.2",
	"words": "Here is a big one. Where floorball is played is richer areas around the world. We should upgrade the graphics to better phones. Reference the Hurling Heroes session, we upgraded to Vulkan I believe and made all the graphics better. Do that. If you need to use Meshy to create better players etc do that."}


## The game draws with Vulkan (the Mobile renderer) on Android, GL Compatibility only as the fallback; and it has a
## High level above Medium for the better phones.
func check() -> void:
	var method := String(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ProjectSettings.get_setting("rendering/renderer/rendering_method", "")))
	info("Android renderer: %s; levels %s" % [method, [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]])
	expect(method == "mobile", "Android draws with '%s', not Vulkan (mobile)" % method)
	expect(Game.GFX_HIGH > Game.GFX_MEDIUM, "no High level")
