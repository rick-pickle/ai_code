class_name Interactable
extends Area2D

signal interacted(dialogue_id: String)
signal interaction_failed(reason: String)

@export var dialogue_id := ""
@export var prompt_text := "Interact"
@export var required_actor_group := ""
@export var dialogue_layer_path: NodePath
@export var interact_actions: Array[StringName] = [&"ui_accept", &"interact"]
@export var show_prompt_when_in_range := true
@export var required_flags: Array[String] = []
@export var blocked_by_flags: Array[String] = []
@export var locked_text := ""
@export var repeat_text: Array[String] = []
@export var base_text: Array[String] = []
@export var effects: Array[String] = []
@export var conditional_text: Array = []
@export var dialogue_ids: Array[String] = []

var _targets_in_range: Array[Node] = []

@onready var prompt_label: Label = get_node_or_null("Prompt") as Label


func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_target_entered)
	body_exited.connect(_on_target_exited)
	area_entered.connect(_on_target_entered)
	area_exited.connect(_on_target_exited)
	_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not _has_target_in_range():
		return
	if not _can_show_interaction():
		return

	for action in interact_actions:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			interact()
			return


func interact() -> bool:
	if not _can_show_interaction():
		return false

	var active_dialogue_id := _resolve_dialogue_id()
	if active_dialogue_id.strip_edges().is_empty():
		return _fail("Interactable has no dialogue_id.")

	if _uses_runtime_dialogue():
		_register_runtime_dialogue(active_dialogue_id)

	var dialogue_layer := _find_dialogue_layer()
	if dialogue_layer == null:
		return _fail("DialogueLayer was not found.")
	if not dialogue_layer.has_method("start_dialogue"):
		return _fail("DialogueLayer is missing start_dialogue.")

	var started := bool(dialogue_layer.call("start_dialogue", active_dialogue_id))
	if not started:
		return _fail("Dialogue failed to start: %s" % active_dialogue_id)

	interacted.emit(active_dialogue_id)
	return true


func _on_target_entered(target: Node) -> void:
	if not _accepts_target(target) or _targets_in_range.has(target):
		return
	_targets_in_range.append(target)
	_refresh_prompt()


func _on_target_exited(target: Node) -> void:
	_targets_in_range.erase(target)
	_refresh_prompt()


func _accepts_target(target: Node) -> bool:
	var group_name := required_actor_group.strip_edges()
	if group_name.is_empty():
		return true
	return target.is_in_group(group_name)


func _has_target_in_range() -> bool:
	return not _targets_in_range.is_empty()


func _find_dialogue_layer() -> Node:
	if dialogue_layer_path != NodePath(""):
		var configured_layer := get_node_or_null(dialogue_layer_path)
		if configured_layer != null:
			return configured_layer

	var tree := get_tree()
	if tree == null:
		return null

	var grouped_layer := tree.get_first_node_in_group("dialogue_layer")
	if grouped_layer != null:
		return grouped_layer

	return tree.root.find_child("DialogueLayer", true, false)


func _refresh_prompt() -> void:
	if prompt_label == null:
		return
	prompt_label.text = _prompt_message()
	prompt_label.visible = show_prompt_when_in_range and _has_target_in_range() and _can_show_interaction()


func _prompt_message() -> String:
	var target_name := prompt_text.strip_edges()
	if target_name.is_empty():
		target_name = "互动"
	return "按确认互动：%s" % target_name


func is_available() -> bool:
	return _flags_satisfied(required_flags) and not _has_any_flag(blocked_by_flags)


func _can_show_interaction() -> bool:
	if _has_any_flag(blocked_by_flags):
		return false
	if _flags_satisfied(required_flags):
		return true
	return not locked_text.strip_edges().is_empty()


func _resolve_dialogue_id() -> String:
	var candidates := dialogue_ids.duplicate()
	if candidates.is_empty() and not dialogue_id.strip_edges().is_empty():
		candidates.append(dialogue_id)

	var best_id := ""
	var best_priority := -999999
	for candidate in candidates:
		var candidate_id := str(candidate).strip_edges()
		if candidate_id.is_empty():
			continue
		var dialogue := _dialogue_data(candidate_id)
		if dialogue.is_empty():
			if best_id.is_empty():
				best_id = candidate_id
			continue
		if not _dialogue_available(dialogue):
			continue
		var priority := int(dialogue.get("priority", 0))
		if best_id.is_empty() or priority > best_priority:
			best_id = candidate_id
			best_priority = priority
	return best_id


func _dialogue_available(dialogue: Dictionary) -> bool:
	return _flags_satisfied(_string_array(dialogue.get("required_flags", []))) and not _has_any_flag(_string_array(dialogue.get("blocked_by_flags", [])))


func _dialogue_data(candidate_id: String) -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null:
		return {}
	var dialogues = registry.get("dialogues")
	if typeof(dialogues) == TYPE_DICTIONARY and dialogues.has(candidate_id):
		var dialogue = dialogues[candidate_id]
		if typeof(dialogue) == TYPE_DICTIONARY:
			return dialogue
	return {}


func _uses_runtime_dialogue() -> bool:
	return not base_text.is_empty() or not repeat_text.is_empty() or not locked_text.strip_edges().is_empty() or not effects.is_empty() or not conditional_text.is_empty()


func _register_runtime_dialogue(active_dialogue_id: String) -> void:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null:
		return

	var selected := _select_text_and_effects()
	var lines: Array = []
	for text in selected.get("text", []):
		lines.append({
			"speaker": "system",
			"portrait": "",
			"text": str(text)
		})

	if lines.is_empty():
		lines.append({
			"speaker": "system",
			"portrait": "",
			"text": prompt_text
		})

	var dialogues = registry.get("dialogues")
	if typeof(dialogues) != TYPE_DICTIONARY:
		dialogues = {}
	dialogues[active_dialogue_id] = {
		"id": active_dialogue_id,
		"lines": lines,
		"choices": [],
		"effects": selected.get("effects", [])
	}
	registry.set("dialogues", dialogues)


func _select_text_and_effects() -> Dictionary:
	if not _flags_satisfied(required_flags):
		if not locked_text.strip_edges().is_empty():
			return {"text": [locked_text], "effects": []}
		return {"text": [], "effects": []}

	if _has_any_flag(blocked_by_flags):
		return {"text": [], "effects": []}

	for raw_entry in conditional_text:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		if _flags_satisfied(_string_array(entry.get("required_flags", []))) and not _has_any_flag(_string_array(entry.get("blocked_by_flags", []))):
			return {
				"text": _string_array(entry.get("text", [])),
				"effects": _string_array(entry.get("effects", []))
			}

	return {"text": base_text, "effects": effects}


func _flags_satisfied(flags: Array[String]) -> bool:
	var game_state := get_node_or_null("/root/GameState")
	for flag_id in flags:
		if game_state == null or not game_state.has_method("has_flag") or not bool(game_state.call("has_flag", flag_id)):
			return false
	return true


func _has_any_flag(flags: Array[String]) -> bool:
	var game_state := get_node_or_null("/root/GameState")
	for flag_id in flags:
		if game_state != null and game_state.has_method("has_flag") and bool(game_state.call("has_flag", flag_id)):
			return true
	return false


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			result.append(str(item))
	elif typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty():
		result.append(str(value))
	return result


func _fail(reason: String) -> bool:
	interaction_failed.emit(reason)
	push_warning(reason)
	return false
