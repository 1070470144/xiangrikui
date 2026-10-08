extends RefCounted

var failures: Array[String] = []

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> Array[String]:
	test_core_economy()
	test_combat_units()
	test_seven_night_schedule()
	return failures

func test_core_economy() -> void:
	var balance := _load_script("res://scripts/balance.gd")
	if balance == null:
		return
	expect(balance.MOTHER_MAX_HEALTH == 300.0, "mother health must match balance document")
	expect(balance.STARTING_ENERGY == 55 and balance.MAX_ENERGY == 100, "energy limits must match balance document")
	expect(balance.DAY_ENERGY_REGEN == 1.0, "day energy regeneration must be one per second")
	expect(balance.STARTING_SEEDS == 5 and balance.MAX_SEEDS == 12, "seed limits must match balance document")
	expect(balance.REPAIR_COST == 20 and balance.REPAIR_AMOUNT == 45.0, "repair economy must match balance document")
	expect(balance.SUNBURST_COST == 40 and balance.SUNBURST_DAMAGE == 90.0, "sunburst values must match balance document")

func test_combat_units() -> void:
	var balance := _load_script("res://scripts/balance.gd")
	if balance == null:
		return
	var enemies: Array = balance.ENEMIES
	expect(enemies.size() == 10, "balance must define ten enemy archetypes")
	expect(enemies[0]["health"] == 72.0 and enemies[0]["reward"] == 5, "shadow beast values must match document")
	expect(enemies[1]["health"] == 48.0 and enemies[1]["reward"] == 4, "erosion bug values must match document")
	expect(enemies[2]["health"] == 750.0 and enemies[2]["reward"] == 30, "root colossus values must match document")
	expect(enemies[3]["health"] == 1300.0 and enemies[3]["reward"] == 50, "sun devourer values must match document")
	var plants: Array = balance.PLANTS
	expect(plants[0]["damage"] == 14.0 and plants[0]["interval"] == 0.64, "thorn values must match document")
	expect(plants[1]["damage"] == 30.0 and plants[1]["interval"] == 1.05, "prism values must match document")

func test_seven_night_schedule() -> void:
	var balance := _load_script("res://scripts/balance.gd")
	if balance == null: return
	var totals := [240, 410, 590, 770, 960, 0, 1310]
	expect(balance.WAVES.size() == 7, "campaign must contain seven nights")
	for index in 7:
		var wave: Array = balance.WAVES[index]
		expect(wave.size() == totals[index], "planned night count mismatch")
		for kind in balance.NIGHT_CONFIGS[index].counts:
			expect(_count_kind(wave, kind) == balance.NIGHT_CONFIGS[index].counts[kind], "composition mismatch")
	expect(_count_kind(balance.WAVES[4], 2) == 10, "ten root colossi in the tenfold wave")
	expect(_count_kind(balance.WAVES[6], 3) == 10, "ten final bosses in the tenfold wave")
	expect(balance.WAVES[5].is_empty(), "night six remains resupply")
func _count_kind(wave: Array, kind: int) -> int:
	var count := 0
	for entry in wave:
		if int(entry["kind"]) == kind:
			count += 1
	return count

func _last_spawn(wave: Array) -> float:
	var result := 0.0
	for entry in wave:
		result = maxf(result, float(entry["time"]))
	return result

func _load_script(path: String) -> Script:
	var script := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null or not script.can_instantiate():
		failures.append("script failed to compile: %s" % path)
		return null
	return script
