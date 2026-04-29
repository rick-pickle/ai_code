class_name MapExit
extends Area2D

signal exit_requested(exit_data: Dictionary)
signal exit_locked(locked_text: String)

@export var interact_actions: Array[StringName] = [&"ui_accept", &"interact"]
@export var required_actor_group := "player"

var exit_data: Dictionary = {}
var required_flags: Array[String] = []
var blocked_by_flags: Array[String] = []
var locked_text := ""

var _targets_in_range: Array[Node] = []


func _ready() -> void:
	add_to_group("map_exit")
	body_entered.connect(_on_target_entered)
	body_exited.connect(_on_target_exited)
	area_entered.connect(_on_target_entered)
	area_exited.connect(_on_target_exited)


func _unhandled_input(event: InputEvent) -> void:
	if _targets_in_range.is_empty():
		return

	for action in interact_actions:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			try_exit()
			return


func configure(data: Dictionary) -> void:
	exit_data = data.duplicate(true)
	required_flags = _string_array(data.get("required_flags", []))
	blocked_by_flags = _string_array(data.get("blocked_by_flags", []))
	locked_text = str(data.get("locked_text", ""))


func try_exit() -> bool:
	if not _flags_satisfied(required_flags) or _has_any_flag(blocked_by_flags):
		exit_locked.emit(locked_text)
		return false

	exit_requested.emit(exit_data)
	return true


func _on_target_entered(target: Node) -> void:
	if not _accepts_target(target) or _targets_in_range.has(target):
		return
	_targets_in_range.append(target)


func _on_target_exited(target: Node) -> void:
	_targets_in_range.erase(target)


func _accepts_target(target: Node) -> bool:
	var group_name := required_actor_group.strip_edges()
	if group_name.is_empty():
		return true
	return target.is_in_group(group_name)


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
