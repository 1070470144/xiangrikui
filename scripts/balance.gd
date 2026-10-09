extends RefCounted

const MOTHER_MAX_HEALTH := 300.0
const LIGHT_NODE_MAX_HEALTH := 100.0
const LIGHT_NODE_CAPACITY := 4
const LIGHT_NODE_SUPPLY_RADIUS := 190.0
const MOTHER_SUPPLY_RADIUS := 225.0
const STORED_LIGHT_DURATION := 3.0
const LOW_LIGHT_DURATION := 4.0
const LOW_LIGHT_DAMAGE_MULTIPLIER := 0.5
const LOW_LIGHT_INTERVAL_MULTIPLIER := 2.0
const STARTING_ENERGY := 55
const MAX_ENERGY := 100
const DAY_ENERGY_REGEN := 1.0
const STARTING_SEEDS := 8
const MAX_SEEDS := 18
const DAY_LIGHT_SPROUT_COST := 15
const NIGHT_LIGHT_SPROUT_COST := 23
const REPAIR_COST := 20
const REPAIR_AMOUNT := 45.0
const SUNBURST_COST := 40
const SUNBURST_RADIUS := 150.0
const SUNBURST_DAMAGE := 90.0
const NIGHT_SEED_REWARD := 5
const NIGHT_FOUR_ENERGY_REWARD := 15
const RESUPPLY_ENERGY := 40
const RESUPPLY_SEEDS := 8
const RESUPPLY_HEAL := 60.0
const FIRST_DAY_DURATION := 45.0
const DAY_DURATION := 45.0
const RESUPPLY_DURATION := 45.0

const PLANTS := [
	{"health": 115.0, "range": 115.0, "damage": 14.0, "interval": 0.64, "seed_cost": 1},
	{"health": 115.0, "range": 235.0, "damage": 30.0, "interval": 1.05, "seed_cost": 2},
]

const ENEMIES := [
	{"name": "影兽", "health": 72.0, "speed": 52.0, "damage": 12.0, "interval": 1.10, "range": 44.0, "reward": 5, "targets_nodes": false},
	{"name": "蚀芽虫", "health": 48.0, "speed": 70.0, "damage": 16.0, "interval": 0.90, "range": 32.0, "reward": 4, "targets_nodes": true},
	{"name": "根冠巨像", "health": 750.0, "speed": 24.0, "damage": 28.0, "interval": 1.50, "range": 58.0, "reward": 30, "targets_nodes": false},
	{"name": "太阳吞噬者", "health": 1300.0, "speed": 20.0, "damage": 34.0, "interval": 1.40, "range": 64.0, "reward": 50, "targets_nodes": false},
	{"name": "枯壳撞兽", "health": 105.0, "speed": 42.0, "damage": 14.0, "interval": 1.20, "range": 46.0, "reward": 7, "targets_nodes": false},
	{"name": "腐孢蛾", "health": 55.0, "speed": 46.0, "damage": 8.0, "interval": 1.80, "range": 150.0, "reward": 6, "targets_nodes": false},
	{"name": "噬灯兽", "health": 80.0, "speed": 58.0, "damage": 10.0, "interval": 1.00, "range": 38.0, "reward": 8, "targets_nodes": true},
	{"name": "腐根祭虫", "health": 95.0, "speed": 38.0, "damage": 9.0, "interval": 1.40, "range": 115.0, "reward": 10, "targets_nodes": false},
	{"name": "裂影体", "health": 90.0, "speed": 50.0, "damage": 13.0, "interval": 1.10, "range": 42.0, "reward": 8, "targets_nodes": false},
	{"name": "黑甲育虫", "health": 190.0, "speed": 30.0, "damage": 20.0, "interval": 1.50, "range": 50.0, "reward": 12, "targets_nodes": false},
]

const NIGHT_CONFIGS := [
	 {"counts":{0:192}, "duration":45.0, "health":0.85, "damage":0.80, "budget":60},
	 {"counts":{0:208,1:80,4:40}, "duration":55.0, "health":0.90, "damage":0.85, "budget":100},
	 {"counts":{0:256,1:160,5:56}, "duration":65.0, "health":0.95, "damage":0.90, "budget":130},
	 {"counts":{0:320,1:192,6:64,7:40}, "duration":75.0, "health":1.0, "damage":0.95, "budget":160},
	 {"counts":{0:400,1:224,8:72,9:64,2:8}, "duration":90.0, "health":1.0, "damage":1.0, "budget":200},
 {"counts":{}, "duration":0.0, "health":1.0, "damage":1.0, "budget":0},
	 {"counts":{0:576,4:192,5:168,8:104,3:8}, "duration":110.0, "health":1.05, "damage":1.0, "budget":250},
]
static var WAVES: Array = _build_wave_templates()

static func _build_wave_templates() -> Array:
 var result: Array = []
 for config in NIGHT_CONFIGS:
  var wave: Array = []
  for kind in config.counts:
   for index in int(config.counts[kind]): wave.append({"kind":kind})
  result.append(wave)
 return result
