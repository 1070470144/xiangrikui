extends RefCounted

const Fog = preload("res://scripts/night_fog.gd")
var failures: Array[String] = []

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func sample(fog: Node, point: Vector2) -> float:
	var pixel := Vector2i((point / fog.VIEW_SIZE * fog.REVEAL_TEXTURE_SIZE).floor()).clamp(Vector2i.ZERO, Vector2i.ONE * (fog.REVEAL_TEXTURE_SIZE - 1))
	return fog._reveal_image.get_pixelv(pixel).r

func run() -> Array[String]:
	var fog := Fog.new()
	var point := Vector2(505, 505)
	var sources: Array[Dictionary] = [{"id":1, "position":point, "radius":120.0}]
	fog.set_reveal_sources(sources)
	fog._advance_reveal(0.025)
	expect(fog._reveal_image == null, "mask updates at 20 Hz, not every frame")
	fog._advance_reveal(0.225)
	expect(absf(sample(fog, point) - 0.5) < 0.01, "new source fades in at half strength after 0.25 seconds")
	fog._advance_reveal(0.25)
	expect(sample(fog, point) == 1.0, "source fully reveals after 0.5 seconds")
	expect(sample(fog, point + Vector2(110, 0)) == 1.0, "inner plant radius remains clear")
	expect(absf(sample(fog, point + Vector2(150, 0)) - 0.5) < 0.01, "outer 60 pixel edge is soft")
	expect(sample(fog, point + Vector2(190, 0)) == 0.0, "outside radius remains foggy")
	var original := fog._reveal_image.get_data()
	fog.set_reveal_sources(sources)
	fog._advance_reveal(0.5)
	expect(fog._reveal_image.get_data() == original, "repeated source updates do not restart fading")
	sources.append({"id":2, "position":point, "radius":120.0})
	fog.set_reveal_sources(sources)
	fog._advance_reveal(0.5)
	expect(fog._reveal_image.get_data() == original, "overlapping sources use maximum, not added brightness")
	sources.clear()
	fog.set_reveal_sources(sources)
	fog._advance_reveal(0.25)
	expect(fog._reveal_sources.size() == 2 and absf(sample(fog, point) - 0.5) < 0.01, "removed objects retain data for a smooth fade out")
	sources.append({"id":1, "position":point, "radius":120.0})
	fog.set_reveal_sources(sources)
	fog._advance_reveal(0.25)
	expect(sample(fog, point) == 1.0 and fog._reveal_sources.size() == 1, "restoring during fade reverses smoothly and expires absent sources")
	sources.clear()
	fog.set_reveal_sources(sources)
	fog._advance_reveal(0.5)
	expect(sample(fog, point) == 0.0 and fog._reveal_sources.is_empty(), "removed source leaves no permanent exploration")
	for i in range(40):
		sources.append({"id":100 + i, "position":Vector2(100 + (i % 8) * 330, 100 + (i / 8) * 500), "radius":90.0})
	sources.append({"id":200, "position":Vector2.ZERO, "radius":120.0})
	sources.append({"id":201, "position":Vector2(2880, 2880), "radius":120.0})
	fog.set_reveal_sources(sources)
	fog._advance_reveal(0.5)
	expect(fog._reveal_sources.size() == 42, "vision sources are not capped at 32")
	for source in sources: expect(sample(fog, source.position) == 1.0, "every source, including map edges, opens vision")
	fog.clear_reveal_sources()
	expect(fog._reveal_sources.is_empty() and sample(fog, point) == 0.0, "reset immediately clears exploration and pending fades")
	expect(fog._reveal_image.get_format() == Image.FORMAT_R8 and fog._reveal_image.get_size() == Vector2i(288, 288), "mask is a 288 square single channel image")
	fog.free()
	return failures
