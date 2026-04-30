extends Node2D

const PLAYER_SCENE := preload("res://scenes/prefabs/Player.tscn")
const INTERACTABLE_SCENE := preload("res://scenes/prefabs/Interactable.tscn")
const NPC_SCENE := preload("res://scenes/prefabs/NPC.tscn")
const MAP_EXIT_SCRIPT := preload("res://scripts/prefabs/map_exit.gd")
const BATTLE_SCENE := preload("res://scenes/battle/BattleScene.tscn")
const RainlampThemeScript := preload("res://scripts/ui/rainlamp_theme.gd")

@export var start_map_id := "post_office"

@onready var world: Node2D = $World
@onready var ui_layer: CanvasLayer = $UILayer
@onready var dialogue_layer: DialogueLayer = $DialogueLayer

var current_map_id := ""
var current_map_data: Dictionary = {}
var current_map: Node2D
var player: Node2D
var active_battle: Node
var objective_panel: PanelContainer
var objective_label: Label


func _ready() -> void:
	_ensure_registry_loaded()
	_create_objective_hint()
	dialogue_layer.dialogue_started.connect(_on_dialogue_started)
	dialogue_layer.dialogue_finished.connect(_on_dialogue_finished)
	player = PLAYER_SCENE.instantiate() as Node2D
	load_map(start_map_id)


func load_map(map_id: String, spawn_id: String = "") -> void:
	_ensure_registry_loaded()
	var map_data := _map_data(map_id)
	if map_data.is_empty():
		push_warning("Missing map data: %s" % map_id)
		return

	_clear_world()
	current_map_id = map_id
	current_map_data = map_data
	var map_scene := _load_map_scene(map_data)
	if map_scene == null:
		print("Using generated reference layout for map: %s" % map_id)
		current_map = _create_generated_map(map_data)
	else:
		current_map = map_scene.instantiate() as Node2D
	if current_map == null:
		push_warning("Map scene root must be a Node2D: %s" % map_id)
		return
	world.add_child(current_map)
	_disable_embedded_cameras(current_map)
	_apply_on_enter_flags(map_data)
	_spawn_blockers(map_data)
	_spawn_interactables(map_data)
	_spawn_npcs(map_data)
	_spawn_exits(map_data)

	if player.get_parent() != world:
		world.add_child(player)
	var resolved_spawn_id := spawn_id
	if resolved_spawn_id.strip_edges().is_empty():
		resolved_spawn_id = str(map_data.get("default_spawn_id", "player_start"))
	player.global_position = _spawn_position(map_data, resolved_spawn_id)
	_configure_player_bounds()
	_refresh_objective_hint()
	_refresh_objective_marker()


func start_encounter(encounter_id: String) -> void:
	print("GAME_ROOT_STAGE start_encounter begin id=%s old_battle_valid=%s" % [encounter_id, active_battle != null and is_instance_valid(active_battle)])
	if active_battle != null and is_instance_valid(active_battle):
		active_battle.queue_free()
		active_battle = null
	_set_objective_visible(false)

	active_battle = BATTLE_SCENE.instantiate()
	active_battle.set("auto_start_debug", false)
	ui_layer.add_child(active_battle)
	print("GAME_ROOT_STAGE start_encounter added id=%s node_path=%s" % [encounter_id, active_battle.get_path()])
	if active_battle.has_signal("battle_finished"):
		active_battle.connect("battle_finished", Callable(self, "_on_battle_finished"))
	if active_battle.has_method("start_encounter"):
		active_battle.call_deferred("start_encounter", encounter_id)
	else:
		push_warning("BattleScene is missing start_encounter.")


func _clear_world() -> void:
	for child in world.get_children():
		if child == player:
			continue
		world.remove_child(child)
		child.queue_free()


func _refresh_runtime_entities() -> void:
	if current_map == null or current_map_data.is_empty():
		return
	for node_name in ["RuntimeBlockers", "RuntimeInteractables", "RuntimeNPCs", "RuntimeExits", "RuntimeObjectiveMarker"]:
		var runtime_node := current_map.get_node_or_null(node_name)
		if runtime_node != null:
			current_map.remove_child(runtime_node)
			runtime_node.queue_free()
	_spawn_blockers(current_map_data)
	_spawn_interactables(current_map_data)
	_spawn_npcs(current_map_data)
	_spawn_exits(current_map_data)
	_refresh_objective_hint()
	_refresh_objective_marker()


func _spawn_interactables(map_data: Dictionary) -> void:
	var interactables_parent := Node2D.new()
	interactables_parent.name = "RuntimeInteractables"
	current_map.add_child(interactables_parent)

	var items := _interactables_for_map(str(map_data.get("id", "")), map_data)
	for item in items:
		var item_required_flags := _string_array(item.get("required_flags", []))
		var item_blocked_flags := _string_array(item.get("blocked_by_flags", []))
		var item_locked_text := str(item.get("locked_text", ""))
		if _has_any_flag(item_blocked_flags):
			continue
		if not _flags_satisfied(item_required_flags) and item_locked_text.strip_edges().is_empty():
			continue

		var interactable := INTERACTABLE_SCENE.instantiate() as Interactable
		interactable.name = str(item.get("id", "Interactable"))
		interactable.dialogue_id = str(item.get("dialogue_id", item.get("id", "")))
		interactable.prompt_text = str(item.get("display_name", "Interact"))
		interactable.required_actor_group = "player"
		interactable.required_flags = item_required_flags
		interactable.blocked_by_flags = item_blocked_flags
		interactable.locked_text = item_locked_text
		interactable.repeat_text = _string_array(item.get("repeat_text", []))
		interactable.base_text = _string_array(item.get("text", []))
		interactable.effects = _string_array(item.get("effects", []))
		interactable.conditional_text = item.get("conditional_text", [])
		interactable.position = _map_point(_position_from(item))
		_configure_interactable_shape(interactable, item)
		interactables_parent.add_child(interactable)


func _spawn_blockers(map_data: Dictionary) -> void:
	var blockers: Array = map_data.get("blockers", [])
	if blockers.is_empty():
		return

	var blockers_parent := Node2D.new()
	blockers_parent.name = "RuntimeBlockers"
	current_map.add_child(blockers_parent)

	for raw_blocker in blockers:
		if typeof(raw_blocker) != TYPE_DICTIONARY:
			continue
		var blocker: Dictionary = raw_blocker
		var body := StaticBody2D.new()
		body.name = str(blocker.get("id", "Blocker"))
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var rect := _rect_from(blocker.get("area", {}))
		shape.size = rect.size
		collision.shape = shape
		body.position = rect.position + (rect.size * 0.5)
		body.add_child(collision)
		blockers_parent.add_child(body)


func _spawn_npcs(map_data: Dictionary) -> void:
	var npcs: Array = map_data.get("npcs", [])
	if typeof(npcs) != TYPE_ARRAY:
		return

	var npcs_parent := Node2D.new()
	npcs_parent.name = "RuntimeNPCs"
	current_map.add_child(npcs_parent)

	for raw_npc in npcs:
		if typeof(raw_npc) != TYPE_DICTIONARY:
			continue
		var npc_data: Dictionary = raw_npc
		if not _flags_satisfied(_string_array(npc_data.get("required_flags", []))) or _has_any_flag(_string_array(npc_data.get("blocked_by_flags", []))):
			continue
		if not _npc_has_available_dialogue(npc_data):
			continue

		var npc_id := str(npc_data.get("npc_id", ""))
		var npc_def := _npc_data(npc_id)
		var npc := NPC_SCENE.instantiate() as NPCInteractable
		npc.name = str(npc_data.get("instance_id", npc_id))
		npc.position = _map_point(_position_from(npc_data))
		npcs_parent.add_child(npc)
		npc.configure(npc_data, npc_def)


func _npc_has_available_dialogue(npc_data: Dictionary) -> bool:
	var candidates := _string_array(npc_data.get("dialogue_ids", []))
	var fallback_id := str(npc_data.get("dialogue_id", "")).strip_edges()
	if candidates.is_empty() and not fallback_id.is_empty():
		candidates.append(fallback_id)

	for dialogue_id in candidates:
		var dialogue := _dialogue_data(dialogue_id)
		if dialogue.is_empty():
			continue
		if _flags_satisfied(_string_array(dialogue.get("required_flags", []))) and not _has_any_flag(_string_array(dialogue.get("blocked_by_flags", []))):
			return true
	return false


func _spawn_exits(map_data: Dictionary) -> void:
	var exits: Array = map_data.get("exits", [])
	if typeof(exits) != TYPE_ARRAY:
		return

	var exits_parent := Node2D.new()
	exits_parent.name = "RuntimeExits"
	current_map.add_child(exits_parent)

	for raw_exit in exits:
		if typeof(raw_exit) != TYPE_DICTIONARY:
			continue
		var exit_data: Dictionary = raw_exit
		var area := Area2D.new()
		area.name = str(exit_data.get("id", "MapExit"))
		area.set_script(MAP_EXIT_SCRIPT)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		var rect := _rect_from(exit_data.get("area", {}))
		shape.size = rect.size
		collision.shape = shape
		area.position = rect.position + (rect.size * 0.5)
		area.add_child(collision)
		area.call("configure", exit_data)
		area.connect("exit_requested", Callable(self, "_on_exit_requested"))
		area.connect("exit_locked", Callable(self, "_on_exit_locked"))
		exits_parent.add_child(area)


func _configure_interactable_shape(interactable: Interactable, item: Dictionary) -> void:
	var collision := interactable.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return

	if item.has("area"):
		var rect := _rect_from(item.get("area", {}))
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		collision.position = rect.size * 0.5
		interactable.position = rect.position
		return

	var shape := CircleShape2D.new()
	shape.radius = max(4.0, float(item.get("radius", 24)) * _average_map_scale())
	collision.shape = shape
	collision.position = Vector2.ZERO


func _on_exit_requested(exit_data: Dictionary) -> void:
	var target_map_id := str(exit_data.get("target_map_id", ""))
	var target_spawn_id := str(exit_data.get("target_spawn_id", ""))
	if target_map_id.strip_edges().is_empty():
		push_warning("Map exit has no target_map_id.")
		return
	load_map(target_map_id, target_spawn_id)


func _on_exit_locked(locked_text: String) -> void:
	if locked_text.strip_edges().is_empty():
		return
	_show_runtime_dialogue("runtime_exit_locked", [locked_text], [])


func _on_battle_finished(encounter_id: String, victory: bool, _reward_flags: Array) -> void:
	active_battle = null
	call_deferred("_refresh_runtime_entities")
	if not victory:
		_refresh_objective_hint()
		return
	var encounter := _encounter_data(encounter_id)
	var post_dialogue_id := str(encounter.get("post_battle_dialogue_id", "")).strip_edges()
	if not post_dialogue_id.is_empty() and not _dialogue_data(post_dialogue_id).is_empty():
		dialogue_layer.start_dialogue(post_dialogue_id)
	_refresh_objective_hint()


func _on_dialogue_started(_dialogue_id: String) -> void:
	_set_objective_visible(false)


func _on_dialogue_finished(dialogue_id: String, _applied_effects: Array) -> void:
	var dialogue := _dialogue_data(dialogue_id)
	_apply_effects(_string_array(dialogue.get("effects", [])))
	call_deferred("_refresh_runtime_entities")
	_refresh_objective_hint()


func _apply_effects(effects: Array[String]) -> void:
	var game_state := get_node_or_null("/root/GameState")
	for effect_id in effects:
		if effect_id.begins_with("flag:"):
			var flag_id := effect_id.substr("flag:".length()).strip_edges()
			if game_state != null and game_state.has_method("set_flag") and not flag_id.is_empty():
				game_state.call("set_flag", flag_id, true)
		elif effect_id.begins_with("quest_step:"):
			if game_state != null and game_state.has_method("set_flag"):
				game_state.call("set_flag", effect_id, true)
		elif effect_id.begins_with("encounter:"):
			var encounter_id := effect_id.substr("encounter:".length()).strip_edges()
			if not encounter_id.is_empty():
				start_encounter(encounter_id)
		elif not effect_id.strip_edges().is_empty():
			push_warning("Unsupported effect: %s" % effect_id)


func _create_objective_hint() -> void:
	objective_panel = PanelContainer.new()
	objective_panel.name = "ObjectivePanel"
	objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective_panel.position = Vector2(12, 12)
	objective_panel.custom_minimum_size = Vector2(360, 28)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.visible = false
	objective_panel.add_theme_stylebox_override("panel", RainlampThemeScript.inset_style(Color(0.93, 0.84, 0.64), RainlampThemeScript.SEAL_RED_DARK))
	ui_layer.add_child(objective_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	objective_panel.add_child(margin)

	objective_label = Label.new()
	objective_label.name = "ObjectiveLabel"
	objective_label.text = ""
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 12)
	RainlampThemeScript.apply_label(objective_label, RainlampThemeScript.SEAL_RED_DARK)
	margin.add_child(objective_label)


func _refresh_objective_hint() -> void:
	if objective_panel == null or objective_label == null:
		return
	var text := _objective_text()
	objective_label.text = text
	_set_objective_visible(not text.strip_edges().is_empty() and active_battle == null and not _dialogue_is_open())


func _set_objective_visible(value: bool) -> void:
	if objective_panel != null:
		objective_panel.visible = value


func _dialogue_is_open() -> bool:
	return dialogue_layer != null and dialogue_layer.has_method("is_dialogue_open") and bool(dialogue_layer.call("is_dialogue_open"))


func _objective_text() -> String:
	if not _has_flag("postman_handbook_obtained"):
		return "当前投递：从门口向上走，到柜台正中查看邮差手册"
	if not _has_flag("letter_001_received"):
		return "当前投递：拿起第一封湿信"
	if not _has_flag("tutorial_battle_01_cleared"):
		return "当前投递：处理湿信纸残影"
	if not _has_flag("found_wenheng_bridge"):
		return "当前投递：去雨灯街问路，前往旧石桥找温衡"
	if not _has_flag("bakery_lie_discovered"):
		return "当前投递：去面包店查清回信真相"
	if not _has_flag("tutorial_battle_02_cleared"):
		return "当前投递：回旧石桥调查桥灯影"
	if not _has_flag("bridge_memory_unlocked"):
		return "当前投递：再看桥灯，进入记忆桥"
	if not _has_flag("memory_mailbox_seen") or not _has_flag("memory_unsent_letter_seen"):
		return "当前投递：调查记忆桥上的信箱和未寄出的信"
	if not _has_flag("memory_truth_line_seen"):
		return "当前投递：查看水洼里的最后一句真话"
	if not _has_flag("boss_return_letter_started"):
		return "当前投递：靠近湿信纸旋涡"
	if not _has_flag("letter_001_sent"):
		return "当前投递：寄出无址回信"
	if not _has_flag("thirteenth_letter_seen"):
		return "当前投递：去旧钟楼查看第十三封信"
	return "当前投递：第一封信已归档"


func _has_flag(flag_id: String) -> bool:
	var game_state := get_node_or_null("/root/GameState")
	return game_state != null and game_state.has_method("has_flag") and bool(game_state.call("has_flag", flag_id))


func _refresh_objective_marker() -> void:
	if current_map == null:
		return
	var old_marker := current_map.get_node_or_null("RuntimeObjectiveMarker")
	if old_marker != null:
		current_map.remove_child(old_marker)
		old_marker.queue_free()

	var marker_data := _objective_marker_data()
	if marker_data.is_empty():
		return

	var interactables := current_map.get_node_or_null("RuntimeInteractables")
	if interactables == null:
		return
	var target := interactables.get_node_or_null(str(marker_data.get("target_id", ""))) as Node2D
	if target == null:
		return

	var marker := Node2D.new()
	marker.name = "RuntimeObjectiveMarker"
	marker.z_index = 80
	current_map.add_child(marker)
	var marker_offset: Vector2 = marker_data.get("offset", Vector2(48, -44))
	marker.global_position = target.global_position + marker_offset

	var label := Label.new()
	label.name = "MarkerLabel"
	label.text = str(marker_data.get("text", "v"))
	label.position = Vector2(-34, -18)
	label.custom_minimum_size = Vector2(72, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	RainlampThemeScript.apply_label(label, Color(1.0, 0.86, 0.36))
	marker.add_child(label)


func _objective_marker_data() -> Dictionary:
	if current_map_id == "post_office":
		if not _has_flag("postman_handbook_obtained"):
			return {"target_id": "post_office_handbook", "text": "v 手册", "offset": Vector2(48, -44)}
		if not _has_flag("letter_001_received"):
			return {"target_id": "post_office_first_letter", "text": "v 湿信", "offset": Vector2(28, -44)}

	if current_map_id == "old_stone_bridge" and _has_flag("found_wenheng_bridge") and _has_flag("bakery_lie_discovered") and not _has_flag("bridge_memory_unlocked"):
		return {"target_id": "old_bridge_lamp", "text": "v 桥灯", "offset": Vector2(34, -50)}

	if current_map_id == "memory_bridge" and _has_flag("memory_bridge_seen") and not _has_flag("letter_001_sent"):
		if not _has_flag("memory_mailbox_seen"):
			return {"target_id": "memory_bridge_mailbox", "text": "v 信箱", "offset": Vector2(30, -44)}
		if not _has_flag("memory_unsent_letter_seen"):
			return {"target_id": "memory_bridge_unsent_letter", "text": "v 信纸", "offset": Vector2(30, -44)}
		if not _has_flag("memory_truth_line_seen"):
			return {"target_id": "memory_bridge_truth_pool", "text": "v 水洼", "offset": Vector2(30, -44)}
		if not _has_flag("boss_return_letter_started"):
			return {"target_id": "memory_bridge_boss_trigger", "text": "v 湿信", "offset": Vector2(30, -50)}

	return {}


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


func _show_runtime_dialogue(dialogue_id: String, lines_text: Array[String], effects: Array[String]) -> void:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null:
		return

	var lines: Array = []
	for text in lines_text:
		lines.append({"speaker": "system", "portrait": "", "text": text})

	var dialogues = registry.get("dialogues")
	if typeof(dialogues) != TYPE_DICTIONARY:
		dialogues = {}
	dialogues[dialogue_id] = {
		"id": dialogue_id,
		"lines": lines,
		"choices": [],
		"effects": effects
	}
	registry.set("dialogues", dialogues)
	dialogue_layer.start_dialogue(dialogue_id)


func _interactables_for_map(map_id: String, map_data: Dictionary) -> Array[Dictionary]:
	var registry := get_node_or_null("/root/DataRegistry")
	var grouped = registry.get("interactables_by_map") if registry != null else {}
	var source: Array = []
	if typeof(grouped) == TYPE_DICTIONARY and grouped.has(map_id) and typeof(grouped[map_id]) == TYPE_ARRAY:
		source = grouped[map_id]

	var allowed_ids := _string_array(map_data.get("interactable_ids", []))
	if allowed_ids.is_empty():
		var all_items: Array[Dictionary] = []
		for raw_item in source:
			if typeof(raw_item) == TYPE_DICTIONARY:
				all_items.append(raw_item)
		return all_items

	var by_id := {}
	for raw_item in source:
		if typeof(raw_item) == TYPE_DICTIONARY:
			by_id[str(raw_item.get("id", ""))] = raw_item

	var result: Array[Dictionary] = []
	for interactable_id in allowed_ids:
		if by_id.has(interactable_id):
			result.append(by_id[interactable_id])
	return result


func _apply_on_enter_flags(map_data: Dictionary) -> void:
	var flags = map_data.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		return
	var effects: Array[String] = []
	for flag_id in _string_array(flags.get("on_enter", [])):
		effects.append("flag:%s" % flag_id)
	_apply_effects(effects)


func _spawn_position(map_data: Dictionary, spawn_id: String) -> Vector2:
	var spawns: Array = map_data.get("spawns", [])
	if typeof(spawns) == TYPE_ARRAY:
		for raw_spawn in spawns:
			if typeof(raw_spawn) != TYPE_DICTIONARY:
				continue
			var spawn: Dictionary = raw_spawn
			if str(spawn.get("id", "")) == spawn_id:
				return current_map.to_global(_map_point(_position_from(spawn)))

	if current_map != null and current_map.has_method("get_spawn_point"):
		return current_map.call("get_spawn_point", spawn_id)
	return Vector2.ZERO


func _map_point(point: Vector2) -> Vector2:
	return Vector2(point.x * _map_scale().x, point.y * _map_scale().y)


func _rect_from(value) -> Rect2:
	if typeof(value) != TYPE_DICTIONARY:
		return Rect2()
	var origin := _map_point(Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0))))
	var scale := _map_scale()
	var size := Vector2(float(value.get("w", 0.0)) * scale.x, float(value.get("h", 0.0)) * scale.y)
	return Rect2(origin, size)


func _position_from(value: Dictionary) -> Vector2:
	var position = value.get("position", {})
	if typeof(position) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(position.get("x", 0.0)), float(position.get("y", 0.0)))


func _map_scale() -> Vector2:
	var dimensions = current_map_data.get("dimensions", {})
	if typeof(dimensions) != TYPE_DICTIONARY:
		return Vector2.ONE

	var design_size := Vector2(float(dimensions.get("width", 0.0)), float(dimensions.get("height", 0.0)))
	var texture_size := _background_texture_size()
	if design_size.x <= 0.0 or design_size.y <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ONE
	return Vector2(texture_size.x / design_size.x, texture_size.y / design_size.y)


func map_scale_for_smoke() -> Vector2:
	return _map_scale()


func _average_map_scale() -> float:
	var scale := _map_scale()
	return (scale.x + scale.y) * 0.5


func _background_texture_size() -> Vector2:
	if current_map == null:
		return Vector2.ZERO
	var background := current_map.get_node_or_null("Background") as Sprite2D
	if background == null or background.texture == null:
		return Vector2.ZERO
	return background.texture.get_size()


func _configure_player_bounds() -> void:
	var bounds := _map_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	if player.has_method("set_movement_bounds"):
		player.call("set_movement_bounds", bounds)
	if player.has_method("configure_camera_limits"):
		player.call("configure_camera_limits", bounds)


func _map_bounds() -> Rect2:
	var size := _background_texture_size()
	if size.x <= 0.0 or size.y <= 0.0:
		var dimensions = current_map_data.get("dimensions", {})
		if typeof(dimensions) == TYPE_DICTIONARY:
			size = Vector2(float(dimensions.get("width", 0.0)), float(dimensions.get("height", 0.0)))
	if size.x <= 0.0 or size.y <= 0.0:
		return Rect2()

	var margin := Vector2(18, 18)
	var origin := current_map.global_position + margin
	return Rect2(origin, Vector2(max(1.0, size.x - margin.x * 2.0), max(1.0, size.y - margin.y * 2.0)))


func _disable_embedded_cameras(root: Node) -> void:
	if root is Camera2D:
		(root as Camera2D).enabled = false
	for child in root.get_children():
		_disable_embedded_cameras(child)


func _create_generated_map(map_data: Dictionary) -> Node2D:
	var map := Node2D.new()
	map.name = "Generated_%s" % str(map_data.get("id", "Map"))

	var dimensions = map_data.get("dimensions", {})
	var width := 960
	var height := 540
	if typeof(dimensions) == TYPE_DICTIONARY:
		width = max(320, int(dimensions.get("width", width)))
		height = max(240, int(dimensions.get("height", height)))

	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(_generated_map_color(str(map_data.get("map_kind", ""))))
	var texture := ImageTexture.create_from_image(image)
	var background := Sprite2D.new()
	background.name = "Background"
	background.texture = texture
	background.centered = false
	map.add_child(background)

	var title := Label.new()
	title.name = "GeneratedMapLabel"
	title.text = "%s\n参考占位地图" % str(map_data.get("display_name", map_data.get("id", "")))
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 24)
	map.add_child(title)

	var spawns_parent := Node2D.new()
	spawns_parent.name = "Spawns"
	map.add_child(spawns_parent)
	var spawns: Array = map_data.get("spawns", [])
	if typeof(spawns) == TYPE_ARRAY:
		for raw_spawn in spawns:
			if typeof(raw_spawn) != TYPE_DICTIONARY:
				continue
			var spawn: Dictionary = raw_spawn
			var marker := Marker2D.new()
			marker.name = str(spawn.get("id", "spawn"))
			marker.position = _position_from(spawn)
			spawns_parent.add_child(marker)

	return map


func _generated_map_color(map_kind: String) -> Color:
	match map_kind:
		"interior":
			return Color(0.22, 0.18, 0.13, 1.0)
		"bridge":
			return Color(0.12, 0.19, 0.22, 1.0)
		"memory_space":
			return Color(0.18, 0.19, 0.28, 1.0)
		"town_landmark":
			return Color(0.16, 0.23, 0.24, 1.0)
		_:
			return Color(0.13, 0.16, 0.2, 1.0)


func _load_map_scene(map_data: Dictionary) -> PackedScene:
	var scene_id := str(map_data.get("scene_id", ""))
	var candidates: Array[String] = [
		"res://scenes/maps/%s_Reference.tscn" % scene_id,
		"res://scenes/maps/%s.tscn" % scene_id,
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			return load(path) as PackedScene
	return null


func _map_data(map_id: String) -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null:
		return {}
	var maps = registry.get("maps")
	if typeof(maps) == TYPE_DICTIONARY and maps.has(map_id):
		return maps[map_id]
	return {}


func _dialogue_data(dialogue_id: String) -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null:
		return {}
	var dialogues = registry.get("dialogues")
	if typeof(dialogues) == TYPE_DICTIONARY and dialogues.has(dialogue_id):
		return dialogues[dialogue_id]
	return {}


func _npc_data(npc_id: String) -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null:
		return {}
	var npcs = registry.get("npcs")
	if typeof(npcs) == TYPE_DICTIONARY and npcs.has(npc_id):
		var npc = npcs[npc_id]
		if typeof(npc) == TYPE_DICTIONARY:
			return npc
	return {}


func _encounter_data(encounter_id: String) -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null:
		return {}
	var encounters = registry.get("encounters")
	if typeof(encounters) == TYPE_DICTIONARY and encounters.has(encounter_id):
		var encounter = encounters[encounter_id]
		if typeof(encounter) == TYPE_DICTIONARY:
			return encounter
	return {}


func _ensure_registry_loaded() -> void:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null or not registry.has_method("load_all"):
		return
	var maps = registry.get("maps")
	if typeof(maps) != TYPE_DICTIONARY or maps.is_empty():
		registry.call("load_all")


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			result.append(str(item))
	elif typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty():
		result.append(str(value))
	return result
