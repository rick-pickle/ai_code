extends SceneTree

const GAME_ROOT_SCENE := "res://scenes/game_root/GameRoot.tscn"
const MAP_IDS := [
	"post_office",
	"rainlamp_street",
	"bakery",
	"old_stone_bridge",
	"memory_bridge",
	"clocktower_exterior",
]
const ENCOUNTER_IDS := [
	"enc_tutorial_wet_paper",
	"enc_tutorial_bridge_lamp",
	"enc_boss_return_letter",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_root := await _load_game_root()
	if game_root == null:
		_finish()
		return

	await _smoke_maps(game_root)
	await _smoke_encounters(game_root)
	await _cleanup(game_root)
	_finish()


func _load_game_root() -> Node:
	if not ResourceLoader.exists(GAME_ROOT_SCENE):
		_fail("Missing GameRoot scene: %s" % GAME_ROOT_SCENE)
		return null

	var packed := load(GAME_ROOT_SCENE) as PackedScene
	if packed == null:
		_fail("Failed to load GameRoot scene: %s" % GAME_ROOT_SCENE)
		return null

	var game_root := packed.instantiate()
	if game_root == null:
		_fail("Failed to instantiate GameRoot scene.")
		return null

	root.add_child(game_root)
	await process_frame
	await process_frame
	return game_root


func _smoke_maps(game_root: Node) -> void:
	for map_id in MAP_IDS:
		if not game_root.has_method("load_map"):
			_fail("GameRoot is missing load_map().")
			return

		game_root.call("load_map", map_id)
		await process_frame
		await process_frame

		var current_map_id := str(game_root.get("current_map_id"))
		if current_map_id != map_id:
			_fail("Map switch failed: expected %s, got %s" % [map_id, current_map_id])
			continue

		var current_map := game_root.get("current_map") as Node
		if current_map == null:
			_fail("Map %s has no current_map node." % map_id)
			continue

		var background := current_map.get_node_or_null("Background") as Sprite2D
		if background == null:
			_fail("Map %s is missing Background Sprite2D." % map_id)
		elif background.texture == null:
			_fail("Map %s Background has no texture." % map_id)

		var blockers := current_map.get_node_or_null("RuntimeBlockers")
		if blockers == null:
			_fail("Map %s is missing RuntimeBlockers." % map_id)
		elif blockers.get_child_count() <= 0:
			_fail("Map %s RuntimeBlockers has no children." % map_id)


func _smoke_encounters(game_root: Node) -> void:
	if not game_root.has_method("start_encounter"):
		_fail("GameRoot is missing start_encounter().")
		return

	for encounter_id in ENCOUNTER_IDS:
		game_root.call("start_encounter", encounter_id)
		await process_frame
		await process_frame
		await process_frame

		var active_battle := game_root.get("active_battle") as Node
		if active_battle == null or not is_instance_valid(active_battle):
			_fail("Encounter %s did not create an active battle." % encounter_id)
			continue

		var active_encounter_id := str(active_battle.get("active_encounter_id"))
		if active_encounter_id != encounter_id:
			_fail("Encounter start mismatch: expected %s, got %s" % [encounter_id, active_encounter_id])

		var active_enemy_id := str(active_battle.get("active_enemy_id"))
		if active_enemy_id.strip_edges().is_empty():
			_fail("Encounter %s did not resolve an enemy." % encounter_id)

		var machine = active_battle.get("machine")
		if machine == null:
			_fail("Encounter %s did not initialize the battle state machine." % encounter_id)


func _cleanup(game_root: Node) -> void:
	if game_root == null or not is_instance_valid(game_root):
		return

	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_all"):
		audio_manager.call("stop_all")
		await process_frame

	var active_battle := game_root.get("active_battle") as Node
	if active_battle != null and is_instance_valid(active_battle):
		active_battle.queue_free()

	game_root.queue_free()
	await process_frame
	await process_frame
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE_OK maps=%d blockers=%d encounters=%d" % [MAP_IDS.size(), MAP_IDS.size(), ENCOUNTER_IDS.size()])
		quit(0)
		return

	for failure in _failures:
		push_error("SMOKE_FAIL %s" % failure)
	print("SMOKE_FAILED failures=%d" % _failures.size())
	quit(1)


func _fail(message: String) -> void:
	_failures.append(message)
