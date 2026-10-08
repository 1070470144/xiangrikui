extends SceneTree

const Content = preload("res://scripts/content_data.gd")
const Mother = preload("res://scripts/mother_flower.gd")
const Form = preload("res://scripts/mother_form_visual.gd")
const Card = preload("res://scripts/mother_upgrade_choice_card.gd")
var checks := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for path in Content.MOTHER_PATHS:
		for branch in path.branch_ids:
			var mother := Mother.new()
			root.add_child(mother)
			mother.set_process(false)
			assert(mother.choose_path(path.id))
			assert(mother.get_form_id() == path.id)
			for rank in range(1,7):
				var id := "mother_%s_%02d" % [branch,rank]
				assert(mother.choose_evolution(id))
				assert(mother.get_form_id() == id)
				assert(mother.art_sprite.texture.resource_path == Form.texture_path(path.id))
				assert(mother.motion_sprite.visible and mother.motion_sprite.is_playing())
				assert(mother._animation_id == path.id)
				assert(Form.texture_path(id).contains("/mother_forms/"))
				var card := Card.new(); card.configure(id); root.add_child(card)
				assert(card.get_node("Content/MotherPortrait").texture.resource_path == Form.texture_path(id))
				assert(not mother.choose_evolution(id))
				assert(mother.get_form_id() == id)
				checks += 1
				card.free()
			mother.reset_state()
			assert(mother.get_form_id().is_empty())
			assert(mother.art_sprite.texture.resource_path == Form.Art.MOTHER_HEALTHY)
			mother.free()
	var roster = preload("res://scripts/plant_roster.gd")
	for kind in range(2,15):
		var plant := preload("res://scripts/plant.gd").new(); plant.kind = kind; root.add_child(plant); plant.set_process(false)
		assert(plant.art_sprite.texture.resource_path == roster.texture_path(kind))
		assert(roster.texture_path(kind).contains("/plant_expansion/"))
		plant.set_powered(false)
		assert(plant.art_sprite.texture.resource_path == roster.texture_path(kind))
		assert(plant.art_sprite.modulate != Color.WHITE)
		plant.free(); checks += 1
	print("FORM INTEGRATION checks=",checks," failures=0")
	quit(0)
