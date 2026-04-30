class_name DialogueRuntime
extends Node

signal dialogue_started(dialogue_id: String, dialogue: Dictionary)
signal dialogue_line_changed(dialogue_id: String, line_index: int, line: Dictionary)
signal dialogue_choices_requested(dialogue_id: String, choices: Array)
signal dialogue_choice_selected(dialogue_id: String, choice_index: int, choice: Dictionary)
signal dialogue_effect_applied(effect_id: String)
signal dialogue_finished(dialogue_id: String, applied_effects: Array)
signal dialogue_cancelled(dialogue_id: String)
signal dialogue_failed(dialogue_id: String, reason: String)

const DIALOGUE_DIR := "res://data/dialogues"
const FLAG_EFFECT_PREFIX := "flag:"
const QUEST_STEP_EFFECT_PREFIX := "quest_step:"
const ENCOUNTER_EFFECT_PREFIX := "encounter:"

var current_dialogue_id := ""
var current_dialogue: Dictionary = {}
var current_line_index := -1
var is_running := false
var waits_for_choice := false

var _pending_root_choices := false


func start(dialogue_id: String) -> bool:
	var trimmed_id := dialogue_id.strip_edges()
	if trimmed_id.is_empty():
		_fail("", "对话 ID 为空。")
		return false

	var dialogue := _load_dialogue(trimmed_id)
	if dialogue.is_empty():
		_fail(trimmed_id, "找不到对话数据。")
		return false

	var lines: Array = dialogue.get("lines", [])
	if typeof(lines) != TYPE_ARRAY:
		_fail(trimmed_id, "对话 lines 必须是数组。")
		return false

	current_dialogue_id = trimmed_id
	current_dialogue = dialogue
	current_line_index = -1
	is_running = true
	waits_for_choice = false
	_pending_root_choices = false

	dialogue_started.emit(current_dialogue_id, current_dialogue)
	if lines.is_empty():
		return _request_root_choices_or_finish()
	return advance()


func advance() -> bool:
	if not is_running or waits_for_choice:
		return false

	var lines := _current_lines()
	var next_index := current_line_index + 1
	if next_index >= lines.size():
		return _request_root_choices_or_finish()

	current_line_index = next_index
	var line := _as_dictionary(lines[current_line_index])
	_apply_effects(line.get("effects", []))
	dialogue_line_changed.emit(current_dialogue_id, current_line_index, line)

	var choices := _choices_from(line)
	if not choices.is_empty():
		waits_for_choice = true
		_pending_root_choices = false
		dialogue_choices_requested.emit(current_dialogue_id, choices)

	return true


func choose(choice_index: int) -> bool:
	if not is_running or not waits_for_choice:
		return false

	var choices := get_current_choices()
	if choice_index < 0 or choice_index >= choices.size():
		return false

	var was_root_choices := _pending_root_choices
	var choice := _as_dictionary(choices[choice_index])
	_apply_effects(choice.get("effects", []))
	dialogue_choice_selected.emit(current_dialogue_id, choice_index, choice)

	waits_for_choice = false
	_pending_root_choices = false

	if _follow_choice_target(choice):
		return true

	if bool(choice.get("finish", false)) or bool(choice.get("end", false)) or was_root_choices:
		return _finish()

	return advance()


func cancel() -> void:
	if not is_running:
		return
	var cancelled_id := current_dialogue_id
	_clear()
	dialogue_cancelled.emit(cancelled_id)


func get_current_line() -> Dictionary:
	var lines := _current_lines()
	if current_line_index < 0 or current_line_index >= lines.size():
		return {}
	return _as_dictionary(lines[current_line_index])


func get_current_choices() -> Array:
	if not is_running:
		return []
	if _pending_root_choices:
		return _choices_from(current_dialogue)
	return _choices_from(get_current_line())


func has_choices_waiting() -> bool:
	return is_running and waits_for_choice


func _request_root_choices_or_finish() -> bool:
	var root_choices := _choices_from(current_dialogue)
	if not root_choices.is_empty():
		waits_for_choice = true
		_pending_root_choices = true
		dialogue_choices_requested.emit(current_dialogue_id, root_choices)
		return true
	return _finish()


func _finish() -> bool:
	var finished_id := current_dialogue_id
	var applied_effects := _apply_effects(current_dialogue.get("effects", []))
	_clear()
	dialogue_finished.emit(finished_id, applied_effects)
	return true


func _follow_choice_target(choice: Dictionary) -> bool:
	var next_dialogue_id := str(choice.get("dialogue_id", choice.get("next_dialogue", ""))).strip_edges()
	if not next_dialogue_id.is_empty():
		return start(next_dialogue_id)

	if choice.has("next_line"):
		return _go_to_line(int(choice["next_line"]))

	if choice.has("line_index"):
		return _go_to_line(int(choice["line_index"]))

	if not choice.has("next"):
		return false

	var next_value = choice["next"]
	if typeof(next_value) == TYPE_INT or typeof(next_value) == TYPE_FLOAT:
		return _go_to_line(int(next_value))

	var next_text := str(next_value).strip_edges()
	if next_text.is_empty():
		return false

	var line_index := _line_index_by_id(next_text)
	if line_index >= 0:
		return _go_to_line(line_index)

	return start(next_text)


func _go_to_line(line_index: int) -> bool:
	var lines := _current_lines()
	if line_index < 0:
		return false
	if line_index >= lines.size():
		return _request_root_choices_or_finish()
	current_line_index = line_index - 1
	waits_for_choice = false
	_pending_root_choices = false
	return advance()


func _line_index_by_id(line_id: String) -> int:
	var lines := _current_lines()
	for index in range(lines.size()):
		var line := _as_dictionary(lines[index])
		if str(line.get("id", "")) == line_id:
			return index
	return -1


func _current_lines() -> Array:
	var lines: Array = current_dialogue.get("lines", [])
	if typeof(lines) != TYPE_ARRAY:
		return []
	return lines


func _choices_from(container: Dictionary) -> Array:
	var choices: Array = container.get("choices", [])
	if typeof(choices) != TYPE_ARRAY:
		return []
	return choices


func _apply_effects(effects_value) -> Array:
	var effects: Array = []
	if typeof(effects_value) == TYPE_ARRAY:
		effects = effects_value
	elif typeof(effects_value) == TYPE_STRING:
		effects = [effects_value]

	var applied: Array = []
	for raw_effect in effects:
		var effect_id := str(raw_effect).strip_edges()
		if effect_id.is_empty():
			continue
		if effect_id.begins_with(FLAG_EFFECT_PREFIX):
			var flag_id := effect_id.substr(FLAG_EFFECT_PREFIX.length()).strip_edges()
			if not flag_id.is_empty() and _set_flag(flag_id):
				applied.append(effect_id)
				dialogue_effect_applied.emit(effect_id)
		elif effect_id.begins_with(QUEST_STEP_EFFECT_PREFIX) or effect_id.begins_with(ENCOUNTER_EFFECT_PREFIX):
			applied.append(effect_id)
			dialogue_effect_applied.emit(effect_id)
		else:
			push_warning("Unsupported dialogue effect: %s" % effect_id)
	return applied


func _set_flag(flag_id: String) -> bool:
	var game_state := _autoload("GameState")
	if game_state != null and game_state.has_method("set_flag"):
		game_state.call("set_flag", flag_id, true)
		return true

	push_warning("GameState Autoload not found; flag was not written: %s" % flag_id)
	return false


func _load_dialogue(dialogue_id: String) -> Dictionary:
	var registry := _autoload("DataRegistry")
	if registry != null:
		var registry_dialogues = registry.get("dialogues")
		if typeof(registry_dialogues) == TYPE_DICTIONARY and registry_dialogues.has(dialogue_id):
			return _as_dictionary(registry_dialogues[dialogue_id]).duplicate(true)

	var exact_path := DIALOGUE_DIR.path_join("%s.json" % dialogue_id)
	if FileAccess.file_exists(exact_path):
		return _load_dialogue_file(exact_path, dialogue_id)

	for file_name in DirAccess.get_files_at(DIALOGUE_DIR):
		if not file_name.ends_with(".json"):
			continue
		var dialogue := _load_dialogue_file(DIALOGUE_DIR.path_join(file_name), dialogue_id)
		if str(dialogue.get("id", "")) == dialogue_id:
			return dialogue

	return {}


func _load_dialogue_file(path: String, expected_id: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open dialogue file: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid dialogue JSON: %s" % path)
		return {}

	var dialogue := _as_dictionary(parsed)
	if not expected_id.is_empty() and dialogue.has("id") and str(dialogue["id"]) != expected_id:
		return dialogue
	return dialogue


func _autoload(node_name: String) -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(node_name)


func _as_dictionary(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _fail(dialogue_id: String, reason: String) -> void:
	dialogue_failed.emit(dialogue_id, reason)
	push_warning("Dialogue failed: %s %s" % [dialogue_id, reason])


func _clear() -> void:
	current_dialogue_id = ""
	current_dialogue = {}
	current_line_index = -1
	is_running = false
	waits_for_choice = false
	_pending_root_choices = false
