extends RefCounted

# Shared by battlefield and chooser: generated portraits take precedence, while
# botanical geometry keeps each upgrade identifiable before art is available.
const Art = preload("res://scripts/art_library.gd")

static func texture_path(id: String) -> String:
	var path := "res://assets/core/generated/mother_forms/%s.png" % id
	return path if not id.is_empty() and ResourceLoader.exists(path) else Art.MOTHER_HEALTHY

