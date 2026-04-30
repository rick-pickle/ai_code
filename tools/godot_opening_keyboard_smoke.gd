extends SceneTree

const GAME_ROOT_SCENE := "res://scenes/game_root/GameRoot.tscn"

var _failures: Array[String] = []
var _game_root: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("OPENING_KEYBOARD_SMOKE_STAGE begin display=%s headless=%s" % [DisplayServer.get_name(), DisplayServer.get_name().to_lower() == "headless"])
	_reset_flags()
	_game_root = _instantiate(GAME_ROOT_SCENE)
	if _game_root == null:
		_finish()
		return
	root.add_child(_game_root)
	await _wait_frames(12)

	var player := _game_root.get("player") as Node2D
	var handbook := _runtime_interactable("post_office_handbook")
	if player == null:
		_fail("Player was not created")
		_finish()
		return
	if handbook == null:
		_fail("Handbook interactable was not created")
		_finish()
		return

	var start_position := player.global_position
	var reached_seconds := await _walk_until_prompt(handbook, "ui_up", 15.0)
	if reached_seconds < 0.0:
		_fail("Handbook prompt was not reached within 15 seconds using ui_up from spawn")
		_finish()
		return

	var interacted := false
	if handbook.has_method("interact"):
		interacted = bool(handbook.call("interact"))
	if not interacted:
		_fail("Handbook interact() returned false after keyboard walk")
		_finish()
		return

	await _drain_dialogue()
	await _wait_frames(8)
	if not _has_flag("postman_handbook_obtained"):
		_fail("postman_handbook_obtained was not set after handbook dialogue")
		_finish()
		return

	print("OPENING_KEYBOARD_SMOKE_OK reached_prompt_seconds=%.2f start=(%.1f,%.1f) end=(%.1f,%.1f)" % [
		reached_seconds,
		start_position.x,
		start_position.y,
		player.global_position.x,
		player.global_position.y,
	])
	_finish()


func _instantiate(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("Cannot load scene: %s" % path)
		return null
	return packed.instantiate()


func _runtime_interactable(item_id: String) -> Node:
	var current_map := _game_root.get("current_map") as Node
	if current_map == null:
		return null
	var parent := current_map.get_node_or_null("RuntimeInteractables")
	if parent == null:
		return null
	return parent.get_node_or_null(item_id)


func _walk_until_prompt(node: Node, action: StringName, max_seconds: float) -> float:
	Input.action_press(action)
	var frame_limit := int(ceil(max_seconds * 60.0))
	for frame_index in range(frame_limit):
		await physics_frame
		if _prompt_visible(node):
			Input.action_release(action)
			return float(frame_index + 1) / 60.0
	Input.action_release(action)
	return -1.0


func _prompt_visible(node: Node) -> bool:
	var prompt := node.get_node_or_null("Prompt") as Label
	return prompt != null and prompt.visible


func _drain_dialogue() -> void:
	var layer = _game_root.get("dialogue_layer")
	if layer == null:
		return
	for _frame in range(120):
		await process_frame
		if not layer.has_method("is_dialogue_open") or not bool(layer.call("is_dialogue_open")):
			return
		var runtime: Node = layer.get_node_or_null("DialogueRuntime")
		if runtime != null and runtime.has_method("advance"):
			runtime.call("advance")
		else:
			break
	_fail("Dialogue did not finish")


func _reset_flags() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.set("flags", {})


func _has_flag(flag_id: String) -> bool:
	var game_state := root.get_node_or_null("GameState")
	return game_state != null and game_state.has_method("has_flag") and bool(game_state.call("has_flag", flag_id))


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _fail(message: String) -> void:
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	var exit_code := 0
	if _failures.is_empty():
		pass
	else:
		exit_code = 1
		for failure in _failures:
			print("OPENING_KEYBOARD_SMOKE_FAIL %s" % failure)
	_cleanup_runtime_scene()
	_quit_after_cleanup.call_deferred(exit_code)


func _cleanup_runtime_scene() -> void:
	for action in [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_accept", &"interact"]:
		if InputMap.has_action(action):
			Input.action_release(action)

	var audio := root.get_node_or_null("AudioManager")
	if audio != null:
		if audio.has_method("stop_all"):
			audio.call("stop_all")
		for child in audio.get_children():
			if child is AudioStreamPlayer and str(child.name).begins_with("Sfx_"):
				child.queue_free()

	if _game_root != null and is_instance_valid(_game_root):
		var dialogue_layer = _game_root.get("dialogue_layer")
		if dialogue_layer != null and dialogue_layer.has_method("cancel_dialogue"):
			dialogue_layer.call("cancel_dialogue")
		_game_root.queue_free()
		_game_root = null

	var current := current_scene
	if current != null and is_instance_valid(current) and current.name == "GameRoot":
		current.queue_free()


func _quit_after_cleanup(exit_code: int) -> void:
	for _frame in range(24):
		await process_frame
	quit(exit_code)
