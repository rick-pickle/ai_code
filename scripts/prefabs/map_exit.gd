class_name MapExit
extends Area2D

signal exit_requested(exit_data: Dictionary)
signal exit_locked(locked_text: String)

@export var interact_actions: Array[StringName] = [&"ui_accept", &"interact"]
@export var required_actor_group := "player"
@export var show_prompt_when_in_range := true

var exit_data: Dictionary = {}
var required_flags: Array[String] = []
var blocked_by_flags: Array[String] = []
var locked_text := ""
var prompt_text := ""

var _targets_in_range: Array[Node] = []
var _prompt_label: Label


func _ready() -> void:
	add_to_group("map_exit")
	_ensure_prompt_label()
	body_entered.connect(_on_target_entered)
	body_exited.connect(_on_target_exited)
	area_entered.connect(_on_target_entered)
	area_exited.connect(_on_target_exited)
	_refresh_prompt()


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
	prompt_text = str(data.get("label", data.get("id", "出口")))
	_refresh_prompt()


func try_exit() -> bool:
	if not _is_available():
		exit_locked.emit(locked_text)
		return false

	exit_requested.emit(exit_data)
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


func _ensure_prompt_label() -> void:
	if _prompt_label != null:
		return
	_prompt_label = get_node_or_null("Prompt") as Label
	if _prompt_label == null:
		_prompt_label = Label.new()
		_prompt_label.name = "Prompt"
		_prompt_label.position = Vector2(-72, -42)
		_prompt_label.size = Vector2(144, 22)
		_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt_label.z_index = 20
		add_child(_prompt_label)
	_prompt_label.visible = false


func _refresh_prompt() -> void:
	_ensure_prompt_label()
	var target_name := prompt_text.strip_edges()
	if target_name.is_empty():
		target_name = "出口"
	if _is_available():
		_prompt_label.text = "按确认/互动：%s" % target_name
	else:
		_prompt_label.text = "按确认查看：%s" % target_name
	_prompt_label.visible = show_prompt_when_in_range and not _targets_in_range.is_empty()


func _is_available() -> bool:
	if not is_inside_tree():
		return true
	return _flags_satisfied(required_flags) and not _has_any_flag(blocked_by_flags)


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
