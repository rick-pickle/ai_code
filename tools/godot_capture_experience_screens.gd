extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const GAME_ROOT_SCENE := "res://scenes/game_root/GameRoot.tscn"
const DIALOGUE_LAYER_SCENE := "res://scenes/ui/DialogueLayer.tscn"
const SCREENSHOT_DIR := "res://docs/vertical_slice/screenshots"

const BATTLE_CASES := [
	["enc_tutorial_wet_paper", "battle_wet_paper"],
	["enc_tutorial_bridge_lamp", "battle_bridge_lamp"],
	["enc_boss_return_letter", "battle_boss_return_letter"],
]

const DIALOGUE_CASES := [
	["post_office_handbook", "dialogue_handbook", []],
	["post_office_empty_mailbox", "dialogue_empty_mailbox", ["postman_handbook_obtained"]],
	["post_office_first_letter", "dialogue_first_letter", ["postman_handbook_obtained"]],
]

const MARKER_CASES := [
	["post_office", "marker_handbook_start", []],
	["post_office", "marker_first_letter", ["postman_handbook_obtained"]],
	["post_office", "marker_post_office_done", ["postman_handbook_obtained", "letter_001_received"]],
	["old_stone_bridge", "marker_old_bridge_lamp", ["postman_handbook_obtained", "letter_001_received", "tutorial_battle_01_cleared", "found_wenheng_bridge", "bakery_lie_discovered"]],
	["old_stone_bridge", "marker_old_bridge_done", ["postman_handbook_obtained", "letter_001_received", "tutorial_battle_01_cleared", "found_wenheng_bridge", "bakery_lie_discovered", "bridge_memory_unlocked"]],
	["memory_bridge", "marker_memory_mailbox", ["postman_handbook_obtained", "letter_001_received", "tutorial_battle_01_cleared", "found_wenheng_bridge", "bakery_lie_discovered", "tutorial_battle_02_cleared", "bridge_memory_unlocked"]],
	["memory_bridge", "marker_memory_unsent", ["postman_handbook_obtained", "letter_001_received", "tutorial_battle_01_cleared", "found_wenheng_bridge", "bakery_lie_discovered", "tutorial_battle_02_cleared", "bridge_memory_unlocked", "memory_mailbox_seen"]],
	["memory_bridge", "marker_memory_truth_pool", ["postman_handbook_obtained", "letter_001_received", "tutorial_battle_01_cleared", "found_wenheng_bridge", "bakery_lie_discovered", "tutorial_battle_02_cleared", "bridge_memory_unlocked", "memory_mailbox_seen", "memory_unsent_letter_seen"]],
	["memory_bridge", "marker_memory_done", ["postman_handbook_obtained", "letter_001_received", "tutorial_battle_01_cleared", "found_wenheng_bridge", "bakery_lie_discovered", "tutorial_battle_02_cleared", "bridge_memory_unlocked", "memory_mailbox_seen", "memory_unsent_letter_seen", "memory_truth_line_seen", "boss_return_letter_started"]],
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOT_DIR))
	await _capture_all("960", false)
	await _capture_all("max", true)
	if not _failures.is_empty():
		for failure in _failures:
			push_error("EXPERIENCE_SCREENSHOT_FAIL %s" % failure)
		print("EXPERIENCE_SCREENSHOT_FAILED failures=%d" % _failures.size())
		quit(1)
		return
	print("EXPERIENCE_SCREENSHOT_OK dir=%s" % ProjectSettings.globalize_path(SCREENSHOT_DIR))
	quit(0)


func _capture_all(label: String, maximized: bool) -> void:
	await _configure_window(maximized)
	for battle_case in BATTLE_CASES:
		await _capture_battle(str(battle_case[0]), "%s_%s" % [str(battle_case[1]), label])
	for dialogue_case in DIALOGUE_CASES:
		await _capture_dialogue(str(dialogue_case[0]), str(dialogue_case[1]), dialogue_case[2], label)
	await _capture_dialogue_layout_case("p2_dialogue_long_text_%s" % label, true)
	await _capture_dialogue_layout_case("p2_dialogue_many_choices_%s" % label, false)
	for marker_case in MARKER_CASES:
		await _capture_marker(str(marker_case[0]), str(marker_case[1]), marker_case[2], label)


func _configure_window(maximized: bool) -> void:
	if maximized:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 540))
	await _wait_frames(10)


func _capture_battle(encounter_id: String, file_stem: String) -> void:
	var battle := _instantiate(BATTLE_SCENE)
	if battle == null:
		return
	battle.set("auto_start_debug", false)
	root.add_child(battle)
	await _wait_frames(4)
	if battle.has_method("start_encounter"):
		battle.call("start_encounter", encounter_id)
	await _wait_frames(18)
	_save_screen(file_stem)
	battle.queue_free()
	await _wait_frames(4)


func _capture_dialogue(item_id: String, file_stem: String, flags: Array, size_label: String) -> void:
	_reset_flags()
	for flag in flags:
		_set_flag(str(flag))
	var game_root := _instantiate(GAME_ROOT_SCENE)
	if game_root == null:
		return
	root.add_child(game_root)
	await _wait_frames(12)
	if not flags.is_empty() and game_root.has_method("_refresh_runtime_entities"):
		game_root.call("_refresh_runtime_entities")
		await _wait_frames(6)
	var node := _runtime_interactable(game_root, item_id)
	if node == null:
		push_warning("Missing dialogue screenshot interactable: %s" % item_id)
		game_root.queue_free()
		await _wait_frames(4)
		return
	_move_player_to(game_root, node)
	if node.has_method("_on_target_entered"):
		node.call("_on_target_entered", game_root.get("player"))
	await _wait_frames(2)
	if node.has_method("interact"):
		node.call("interact")
	await _wait_frames(10)
	_save_screen("%s_%s" % [file_stem, size_label])
	game_root.queue_free()
	await _wait_frames(4)


func _capture_dialogue_layout_case(file_stem: String, long_text: bool) -> void:
	_register_p2_dialogues()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.13, 0.09, 0.06, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var layer := _instantiate(DIALOGUE_LAYER_SCENE)
	if layer == null:
		backdrop.queue_free()
		return
	root.add_child(layer)
	await _wait_frames(4)
	if layer.has_method("start_dialogue"):
		layer.call("start_dialogue", "p2_long_text" if long_text else "p2_many_choices")
	await _wait_frames(10)
	_assert_dialogue_layout(layer, file_stem, not long_text)
	_save_screen(file_stem)
	layer.queue_free()
	backdrop.queue_free()
	await _wait_frames(6)


func _capture_marker(map_id: String, file_stem: String, flags: Array, size_label: String) -> void:
	_reset_flags()
	for flag in flags:
		_set_flag(str(flag))
	var game_root := _instantiate(GAME_ROOT_SCENE)
	if game_root == null:
		return
	root.add_child(game_root)
	await _wait_frames(12)
	if game_root.has_method("load_map"):
		game_root.call("load_map", map_id)
		await _wait_frames(10)
	var marker := _runtime_marker(game_root)
	print("EXPERIENCE_MARKER map=%s file=%s visible=%s flags=%s" % [map_id, file_stem, marker != null, _join_strings(flags)])
	_save_screen("%s_%s" % [file_stem, size_label])
	game_root.queue_free()
	await _wait_frames(6)


func _instantiate(path: String) -> Node:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Cannot load scene: %s" % path)
		return null
	return packed.instantiate()


func _runtime_interactable(game_root: Node, item_id: String) -> Node:
	var current_map := game_root.get("current_map") as Node
	if current_map == null:
		return null
	var parent := current_map.get_node_or_null("RuntimeInteractables")
	if parent == null:
		return null
	return parent.get_node_or_null(item_id)


func _move_player_to(game_root: Node, node: Node) -> void:
	var player := game_root.get("player") as Node2D
	if player == null:
		return
	var collision := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		player.global_position = collision.global_position
	elif node is Node2D:
		player.global_position = (node as Node2D).global_position


func _save_screen(file_stem: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [SCREENSHOT_DIR, file_stem]
	var result := image.save_png(path)
	print("EXPERIENCE_SCREENSHOT file=%s result=%s size=%dx%d" % [path, result, image.get_width(), image.get_height()])


func _reset_flags() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.set("flags", {})


func _set_flag(flag_id: String) -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null and game_state.has_method("set_flag"):
		game_state.call("set_flag", flag_id, true)


func _runtime_marker(game_root: Node) -> Node:
	var current_map := game_root.get("current_map") as Node
	if current_map == null:
		return null
	return current_map.get_node_or_null("RuntimeObjectiveMarker")


func _assert_dialogue_layout(layer: Node, file_stem: String, expects_choices: bool) -> void:
	var dialog_box := layer.get_node_or_null("Root/DialogBox") as Control
	if dialog_box == null:
		_fail("%s missing dialog box" % file_stem)
		return
	var rect := dialog_box.get_global_rect()
	var viewport_size := root.get_visible_rect().size
	if rect.position.y < 0.0 or rect.end.y > viewport_size.y:
		_fail("%s dialog rect outside viewport rect=%s viewport=%s" % [file_stem, rect, viewport_size])
	var choices_scroll := layer.get_node_or_null("Root/DialogBox/Margin/Content/ChoicesScroll") as Control
	if expects_choices and (choices_scroll == null or not choices_scroll.visible):
		_fail("%s choices scroll was not visible" % file_stem)
	var text_scroll := layer.get_node_or_null("Root/DialogBox/Margin/Content/TextScroll") as Control
	if text_scroll == null:
		_fail("%s text scroll missing" % file_stem)
	print("EXPERIENCE_DIALOGUE_LAYOUT file=%s rect=%s viewport=%s choices=%s" % [file_stem, rect, viewport_size, expects_choices])


func _register_p2_dialogues() -> void:
	var registry := root.get_node_or_null("DataRegistry")
	if registry == null:
		return
	if registry.has_method("load_all"):
		registry.call("load_all")
	var dialogues = registry.get("dialogues")
	if typeof(dialogues) != TYPE_DICTIONARY:
		dialogues = {}
	dialogues["p2_long_text"] = {
		"id": "p2_long_text",
		"lines": [
			{
				"speaker": "system",
				"text": "这是一段用于验证对话框长正文保护的文本。它会故意写得比普通调查句更长，包含雨灯、邮包、桥面、水声、未寄出的信、以及玩家可能在后续版本中遇到的多行说明。对话框应该保持在屏幕底部安全区域内，正文进入滚动范围，而不是把按钮推出屏幕，也不能被窗口底部裁切。"
			}
		]
	}
	dialogues["p2_many_choices"] = {
		"id": "p2_many_choices",
		"lines": [
			{
				"speaker": "system",
				"text": "请选择一条回信处理方式；这里故意提供多项，用来验证选项区域会滚动保护。",
				"choices": [
					{"text": "拆封：先读出表层情绪", "finish": true},
					{"text": "封存：把情绪暂时压回信纸", "finish": true},
					{"text": "退回：把谎言盖上邮戳", "finish": true},
					{"text": "照见：借雨灯看清字迹", "finish": true},
					{"text": "寄出：让信离开原地", "finish": true}
				]
			}
		]
	}
	registry.set("dialogues", dialogues)


func _join_strings(values: Array) -> String:
	var text := ""
	for value in values:
		if not text.is_empty():
			text += ","
		text += str(value)
	return text


func _fail(message: String) -> void:
	_failures.append(message)
	push_warning(message)


func _wait_frames(count: int) -> void:
	for _index in range(count):
		await process_frame
