extends WsgOwnerNote
## The owner, 2026-11-02 (Pok Ta Pok 0.6.x): "the man doing the smoke ritual looks like a block figure"

const NOTE := {"id": "2026-11-02-block-figure", "game": "pok-ta-pok", "date": "2026-11-02", "version": "Pok Ta Pok 0.6.x", "words": "the man doing the smoke ritual looks like a block figure"}

## Every body the foundation draws (a player near and far - full and light detail - and an official) is a skinned
## person, never primitive shapes standing in for one.
func check() -> void:
	var ch := WsgBody.load_character("res://tests/character", "hero")
	var body := WsgBody.new(ch)
	tree.root.add_child(body)
	var off := WsgOfficial.new(ch)
	tree.root.add_child(off)
	await frame()
	for detail in [true, false]:
		body.set_detail(detail)
		var why := WsgNoteChecks.block_figure(body)
		info("a player at %s detail: %s" % ["full" if detail else "light", "a person" if why == "" else why])
		expect(why == "", "a player at %s detail is a block figure: %s" % ["full" if detail else "light", why])
	var why_o := WsgNoteChecks.block_figure(off)
	info("an official: %s" % ("a person" if why_o == "" else why_o))
	expect(why_o == "", "an official is a block figure: %s" % why_o)
	body.queue_free()
	off.queue_free()
