extends SceneTree

const BOOT_SCENE := "res://scenes/boot/Boot.tscn"

var _failures: Array[String] = []
var _game_root: Node
var _boot: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("VISUAL_PLAYTHROUGH_STAGE begin display=%s headless=%s" % [DisplayServer.get_name(), _is_headless()])
	_reset_game_state()
	var boot := _instantiate_scene(BOOT_SCENE)
	if boot == null:
		_finish()
		return
	_boot = boot
	root.add_child(boot)
	_game_root = await _wait_for_game_root()
	if _game_root == null:
		_finish()
		return

	await _step_interactable("post_office", "RuntimeInteractables", "post_office_handbook", ["postman_handbook_obtained"])
	await _step_interactable("post_office", "RuntimeInteractables", "post_office_first_letter", ["letter_001_received"])
	await _finish_battle("enc_tutorial_wet_paper", ["open_seal", "archive_seal", "archive_seal"], ["tutorial_battle_01_cleared"])
	await _step_exit("post_office", "to_rainlamp_street", "rainlamp_street")
	await _step_interactable("rainlamp_street", "RuntimeNPCs", "umbrella_owner_street", ["asked_umbrella_owner_about_wenheng"])
	await _step_interactable("rainlamp_street", "RuntimeNPCs", "rain_counting_child_street", ["asked_child_about_wenheng"])
	await _step_exit("rainlamp_street", "to_old_stone_bridge", "old_stone_bridge")
	await _step_interactable("old_stone_bridge", "RuntimeNPCs", "wenheng_bridge_waiting", ["found_wenheng_bridge"])
	await _step_exit("old_stone_bridge", "to_rainlamp_street", "rainlamp_street")
	await _step_exit("rainlamp_street", "to_bakery", "bakery")
	await _step_interactable("bakery", "RuntimeInteractables", "bakery_red_bean_bun", ["received_red_bean_bun"])
	await _step_interactable("bakery", "RuntimeInteractables", "bakery_linmo_drawer", ["bakery_lie_discovered"])
	await _step_exit("bakery", "to_rainlamp_street", "rainlamp_street")
	await _step_exit("rainlamp_street", "to_old_stone_bridge", "old_stone_bridge")
	await _step_interactable("old_stone_bridge", "RuntimeInteractables", "old_bridge_lamp", [])
	await _finish_battle("enc_tutorial_bridge_lamp", ["open_seal", "return_to_sender", "open_seal"], ["tutorial_battle_02_cleared"])
	await _step_interactable("old_stone_bridge", "RuntimeInteractables", "old_bridge_lamp", ["bridge_memory_unlocked"])
	await _step_exit("old_stone_bridge", "to_memory_bridge", "memory_bridge")
	await _step_interactable("memory_bridge", "RuntimeInteractables", "memory_bridge_mailbox", ["memory_mailbox_seen"])
	await _step_interactable("memory_bridge", "RuntimeInteractables", "memory_bridge_unsent_letter", ["memory_unsent_letter_seen"])
	await _step_interactable("memory_bridge", "RuntimeInteractables", "memory_bridge_truth_pool", ["memory_truth_line_seen"])
	await _step_interactable("memory_bridge", "RuntimeInteractables", "memory_bridge_boss_trigger", ["boss_return_letter_started"])
	await _finish_battle("enc_boss_return_letter", ["open_seal", "send_letter", "return_to_sender", "send_letter"], ["letter_001_sent", "bridge_waiter_resolved"])
	await _step_exit("memory_bridge", "after_boss_to_old_stone_bridge", "old_stone_bridge")
	await _step_exit("old_stone_bridge", "to_rainlamp_street", "rainlamp_street")
	await _step_exit("rainlamp_street", "to_clocktower_exterior", "clocktower_exterior")
	await _step_interactable("clocktower_exterior", "RuntimeInteractables", "clocktower_thirteenth_letter", ["thirteenth_letter_seen"])

	_finish()


func _instantiate_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		_fail("Missing scene: %s" % path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		_fail("Failed to load scene: %s" % path)
		return null
	return packed.instantiate()


func _wait_for_game_root() -> Node:
	for _frame in range(180):
		await process_frame
		var node := root.find_child("GameRoot", true, false)
		if node != null:
			print("VISUAL_PLAYTHROUGH_STAGE boot_loaded current_map=%s" % str(node.get("current_map_id")))
			return node
	_fail("Boot did not create GameRoot")
	return null


func _step_interactable(map_id: String, parent_name: String, node_name: String, expected_flags: Array[String]) -> void:
	var map_ready := await _ensure_map(map_id)
	if not map_ready:
		return
	var node := _runtime_node(parent_name, node_name)
	if node == null:
		_fail("Missing interactable %s.%s" % [map_id, node_name])
		return
	_move_player_to(node)
	if node.has_method("_on_target_entered"):
		node.call("_on_target_entered", _game_root.get("player"))
	await process_frame
	_assert_prompt_visible(node, "%s.%s" % [map_id, node_name])
	var ok := false
	if node.has_method("interact"):
		ok = bool(node.call("interact"))
	if not ok:
		_fail("Interact failed: %s.%s" % [map_id, node_name])
		return
	await _drain_dialogue()
	await _wait_frames(8)
	_assert_flags(expected_flags, "%s.%s" % [map_id, node_name])
	print("VISUAL_PLAYTHROUGH_STEP interact ok map=%s node=%s flags=%s" % [map_id, node_name, _join_strings(expected_flags)])


func _step_exit(map_id: String, exit_name: String, expected_map: String) -> void:
	var map_ready := await _ensure_map(map_id)
	if not map_ready:
		return
	var node := _runtime_node("RuntimeExits", exit_name)
	if node == null:
		_fail("Missing exit %s.%s" % [map_id, exit_name])
		return
	_move_player_to(node)
	if node.has_method("_on_target_entered"):
		node.call("_on_target_entered", _game_root.get("player"))
	await process_frame
	_assert_prompt_visible(node, "%s.%s" % [map_id, exit_name])
	var ok := false
	if node.has_method("try_exit"):
		ok = bool(node.call("try_exit"))
	if not ok:
		_fail("Exit failed: %s.%s" % [map_id, exit_name])
		return
	await _wait_frames(8)
	if str(_game_root.get("current_map_id")) != expected_map:
		_fail("Exit %s.%s reached %s, expected %s" % [map_id, exit_name, str(_game_root.get("current_map_id")), expected_map])
		return
	print("VISUAL_PLAYTHROUGH_STEP exit ok from=%s exit=%s to=%s" % [map_id, exit_name, expected_map])


func _finish_battle(encounter_id: String, skill_ids: Array[String], expected_flags: Array[String]) -> void:
	var battle := await _wait_for_battle(encounter_id)
	if battle == null:
		return
	for skill_id in skill_ids:
		if battle.has_method("_on_command_pressed"):
			battle.call("_on_command_pressed", skill_id)
		await _wait_frames(12)
		var snapshot := _battle_snapshot(battle)
		print("VISUAL_PLAYTHROUGH_BATTLE skill=%s phase=%s obsession=%d seals=%d" % [
			skill_id,
			str(snapshot.get("phase_key", "")),
			int(snapshot.get("enemy_obsession", 0)),
			int(snapshot.get("revealed_layers", 0))
		])
		if str(snapshot.get("phase_key", "")) == "victory":
			break
	var final_snapshot := _battle_snapshot(battle)
	if str(final_snapshot.get("phase_key", "")) != "victory":
		_fail("Battle did not reach victory: %s phase=%s" % [encounter_id, str(final_snapshot.get("phase_key", ""))])
		return
	if battle.has_method("_on_close_pressed"):
		battle.call("_on_close_pressed")
	await _wait_frames(8)
	await _drain_dialogue()
	await _wait_frames(8)
	_assert_flags(expected_flags, encounter_id)
	print("VISUAL_PLAYTHROUGH_STEP battle ok encounter=%s flags=%s" % [encounter_id, _join_strings(expected_flags)])


func _battle_snapshot(battle: Node) -> Dictionary:
	var machine = battle.get("machine")
	if machine != null and machine.has_method("snapshot"):
		return machine.call("snapshot")
	return {}


func _wait_for_battle(encounter_id: String) -> Node:
	for _frame in range(120):
		await process_frame
		var battle := _game_root.get("active_battle") as Node
		if battle != null and is_instance_valid(battle):
			var active_id := str(battle.get("active_encounter_id"))
			if active_id == encounter_id:
				return battle
	_fail("Battle did not start: %s" % encounter_id)
	return null


func _drain_dialogue() -> void:
	var layer = _game_root.get("dialogue_layer")
	if layer == null:
		return
	for _frame in range(120):
		await process_frame
		if not layer.has_method("is_dialogue_open") or not bool(layer.call("is_dialogue_open")):
			return
		var runtime: Node = layer.get_node_or_null("DialogueRuntime")
		if runtime != null and runtime.has_method("has_choices_waiting") and bool(runtime.call("has_choices_waiting")):
			runtime.call("choose", 0)
		elif runtime != null and runtime.has_method("advance"):
			runtime.call("advance")
		else:
			break
	_fail("Dialogue did not finish")


func _ensure_map(map_id: String) -> bool:
	if str(_game_root.get("current_map_id")) == map_id:
		return true
	if _game_root.has_method("load_map"):
		_game_root.call("load_map", map_id)
		await _wait_frames(8)
	return str(_game_root.get("current_map_id")) == map_id


func _runtime_node(parent_name: String, node_name: String) -> Node:
	var current_map := _game_root.get("current_map") as Node
	if current_map == null:
		return null
	var parent := current_map.get_node_or_null(parent_name)
	if parent == null:
		return null
	return parent.get_node_or_null(node_name)


func _move_player_to(node: Node) -> void:
	var player := _game_root.get("player") as Node2D
	if player == null:
		return
	var collision := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		player.global_position = collision.global_position
	elif node is Node2D:
		player.global_position = (node as Node2D).global_position


func _assert_prompt_visible(node: Node, label: String) -> void:
	var prompt := node.get_node_or_null("Prompt") as CanvasItem
	if prompt == null:
		prompt = node.get_node_or_null("NameLabel") as CanvasItem
	if prompt == null or not prompt.visible:
		_fail("Prompt not visible after entering range: %s" % label)


func _assert_flags(flag_ids: Array[String], source: String) -> void:
	for flag_id in flag_ids:
		if not _has_flag(flag_id):
			_fail("Missing flag after %s: %s" % [source, flag_id])


func _has_flag(flag_id: String) -> bool:
	var game_state := root.get_node_or_null("GameState")
	return game_state != null and game_state.has_method("has_flag") and bool(game_state.call("has_flag", flag_id))


func _reset_game_state() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.set("flags", {})


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _join_strings(values: Array[String]) -> String:
	var text := ""
	for value in values:
		if not text.is_empty():
			text += ","
		text += str(value)
	return text


func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"


func _fail(message: String) -> void:
	_failures.append(message)
	print("VISUAL_PLAYTHROUGH_FAIL %s" % message)


func _finish() -> void:
	var exit_code := 0
	if _failures.is_empty():
		print("VISUAL_PLAYTHROUGH_OK steps=18")
	else:
		exit_code = 1
		for failure in _failures:
			push_error("VISUAL_PLAYTHROUGH_FAIL %s" % failure)
		print("VISUAL_PLAYTHROUGH_FAILED failures=%d" % _failures.size())
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
		_game_root.queue_free()
	if _boot != null and is_instance_valid(_boot):
		_boot.queue_free()
	var current := current_scene
	if current != null and is_instance_valid(current) and (current.name == "GameRoot" or current.name == "Boot"):
		current.queue_free()


func _quit_after_cleanup(exit_code: int) -> void:
	for _frame in range(24):
		await process_frame
	quit(exit_code)
