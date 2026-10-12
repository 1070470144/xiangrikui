extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var content = load("res://scripts/content_data.gd")
	assert(content.get_flower("storm_flower").max_targets == 7)
	assert(content.get_flower("prism_flower").max_targets == 4)
	assert(content.get_flower("frost_bell").max_targets == 2)
	assert(content.get_flower("sunwell_flower").interval == 1.0)
	assert(content.get_flower("sunwell_flower").energy == 1)
	var queue: Array = load("res://scripts/wave_director.gd").new().build(7, 42)
	var bosses := 0
	for entry in queue:
		if entry.kind == 3: bosses += 1; assert(entry.time == 0.0)
	assert(bosses == 1)
	var host := Node2D.new(); root.add_child(host)
	var p = load("res://scripts/plant.gd")
	var healer = p.new(); host.add_child(healer); healer.configure(p.Kind.CLEANSE,0); healer.combat_active = true
	var ally = p.new(); host.add_child(ally); ally.configure(p.Kind.THORN,0); ally.position = Vector2(2000,2000); ally.health = ally.max_health * 0.2
	healer._activate_support()
	assert(is_equal_approx(ally.health, ally.max_health * 0.7))
	assert(healer.is_queued_for_deletion())
	var drum = p.new(); host.add_child(drum); drum.configure(p.Kind.DRUM,0); drum.set_powered(true)
	ally.position = Vector2.ZERO
	drum._activate_support()
	assert(ally.inspiration_damage_multiplier == 1.25)
	assert(ally.inspiration_multiplier == 0.78)
	assert(is_equal_approx(ally.get_effective_attack_damage(), ally.attack_damage * 1.25))
	host.queue_free()
	print("CAMPAIGN_PLANT_CHANGES_PASS")
	quit()
