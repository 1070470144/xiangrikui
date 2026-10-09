extends SceneTree

func _initialize() -> void:
	var data = load("res://scripts/content_data.gd")
	var balance = load("res://scripts/balance.gd")
	var plant_script = load("res://scripts/plant.gd")
	for id in load("res://scripts/plant_roster.gd").FLOWER_IDS:
		var tuned: Dictionary = data.get_flower(id)
		assert(tuned.health > 0.0)
		if tuned.has("damage"): assert(tuned.damage > 0.0 and tuned.interval > 0.0)
	var thorn = plant_script.new()
	thorn.configure(0, 0)
	assert(thorn.attack_damage == data.get_flower("thorn_flower").damage)
	assert(thorn.max_health == data.get_flower("thorn_flower").health)
	assert(data.get_flower("storm_flower").max_targets == 8)
	assert(data.get_flower("burst_flower").max_targets == 20)
	assert(data.get_flower("spear_bamboo").max_targets == 10)
	assert(balance.WAVES[0].size() == 192)
	assert(balance.WAVES[4].size() == 768)
	assert(balance.STARTING_SEEDS == 8)
	thorn.free()
	print("SWARM_BALANCE_PASS")
	quit()
