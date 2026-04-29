extends Node

var letters: Dictionary = {}
var dialogues: Dictionary = {}
var enemies: Dictionary = {}
var skills: Dictionary = {}
var encounters: Dictionary = {}
var maps: Dictionary = {}
var npcs: Dictionary = {}
var interactables: Dictionary = {}
var interactables_by_map: Dictionary = {}
var localization: Dictionary = {}

func load_all() -> void:
	letters = _load_json_dir("res://data/letters")
	dialogues = _load_json_dir("res://data/dialogues")
	enemies = _load_json_dir("res://data/enemies")
	skills = _load_collection_file("res://data/skills/core_skills.json", "skills")
	encounters = _load_collection_file("res://data/encounters/vertical_slice_encounters.json", "encounters")
	maps = _load_json_dir("res://data/maps")
	npcs = _load_collection_file("res://data/npcs/vertical_slice_npcs.json", "npcs")
	_load_interactables("res://data/interactables/vertical_slice_interactables.json")
	_merge_npc_dialogues()
	_merge_interactable_dialogues()
	localization = _load_json_file("res://data/localization/zh_cn.json")

func get_text(key: String) -> String:
	return str(localization.get(key, key))

func _load_json_dir(path: String) -> Dictionary:
	var result := {}
	for file_name in DirAccess.get_files_at(path):
		if not file_name.ends_with(".json"):
			continue
		var item: Dictionary = _load_json_file(path.path_join(file_name))
		if item.has("id"):
			result[item["id"]] = item
	return result

func _load_collection_file(path: String, collection_key: String) -> Dictionary:
	var result := {}
	var root: Dictionary = _load_json_file(path)
	for item in root.get(collection_key, []):
		if item.has("id"):
			result[item["id"]] = item
	return result

func _load_interactables(path: String) -> void:
	interactables.clear()
	interactables_by_map.clear()
	var root: Dictionary = _load_json_file(path)
	var grouped = root.get("interactables_by_map", {})
	if typeof(grouped) != TYPE_DICTIONARY:
		return
	for map_id in grouped.keys():
		var items = grouped[map_id]
		if typeof(items) != TYPE_ARRAY:
			continue
		interactables_by_map[map_id] = items
		for item in items:
			if typeof(item) == TYPE_DICTIONARY and item.has("id"):
				interactables[item["id"]] = item

func _merge_npc_dialogues() -> void:
	for npc in npcs.values():
		if typeof(npc) != TYPE_DICTIONARY:
			continue
		var npc_dialogues = npc.get("dialogues", [])
		if typeof(npc_dialogues) != TYPE_ARRAY:
			continue
		for dialogue in npc_dialogues:
			if typeof(dialogue) == TYPE_DICTIONARY and dialogue.has("id"):
				dialogues[dialogue["id"]] = dialogue

func _merge_interactable_dialogues() -> void:
	for item in interactables.values():
		if typeof(item) != TYPE_DICTIONARY or not item.has("id"):
			continue
		var lines: Array = []
		var text_lines = item.get("text", [])
		if typeof(text_lines) == TYPE_ARRAY:
			for text in text_lines:
				lines.append({
					"speaker": "system",
					"portrait": "",
					"text": str(text)
				})
		if lines.is_empty():
			continue
		dialogues[item["id"]] = {
			"id": item["id"],
			"lines": lines,
			"choices": [],
			"effects": item.get("effects", [])
		}

func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid JSON object: %s" % path)
		return {}
	return parsed
