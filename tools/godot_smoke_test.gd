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
const EXPECTED_ENEMY_TEXTURES := {
	"enc_tutorial_wet_paper": "res://assets/sprites/enemies/wet_paper_echo/wet_paper_echo.png",
	"enc_tutorial_bridge_lamp": "res://assets/sprites/enemies/bridge_lamp_shadow/bridge_lamp_shadow.png",
	"enc_boss_return_letter": "res://assets/sprites/enemies/return_letter_idle_3x3/idle-1.png",
}
const MAX_ELAPSED_MS := 60000

var _failures: Array[String] = []
var _started_ms := 0
var _last_stage := "init"


func _init() -> void:
	_started_ms = Time.get_ticks_msec()
	_stage("begin script=%s max_elapsed_ms=%d" % [GAME_ROOT_SCENE, MAX_ELAPSED_MS])
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
	_stage("load_game_root begin")
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
	_stage("load_game_root end node=%s" % game_root.name)
	_report_viewport(game_root)
	if _timed_out():
		return null
	return game_root


func _smoke_maps(game_root: Node) -> void:
	for map_id in MAP_IDS:
		_stage("map begin id=%s" % map_id)
		if not game_root.has_method("load_map"):
			_fail("GameRoot is missing load_map().")
			return

		game_root.call("load_map", map_id)
		await process_frame
		await process_frame
		if _timed_out():
			return

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
		var map_scale := Vector2.ONE
		if game_root.has_method("map_scale_for_smoke"):
			map_scale = game_root.call("map_scale_for_smoke")
		if abs(map_scale.x - map_scale.y) > 0.02 or abs(map_scale.x - 1.0) > 0.02 or abs(map_scale.y - 1.0) > 0.02:
			_fail("Map %s has unsafe reference scale %.3fx%.3f" % [map_id, map_scale.x, map_scale.y])

		var blockers := current_map.get_node_or_null("RuntimeBlockers")
		if blockers == null:
			_fail("Map %s is missing RuntimeBlockers." % map_id)
		elif blockers.get_child_count() <= 0:
			_fail("Map %s RuntimeBlockers has no children." % map_id)
		var blocker_count := blockers.get_child_count() if blockers != null else 0
		var has_texture := background != null and background.texture != null
		_stage("map end id=%s blockers=%d texture=%s scale=%.3fx%.3f" % [map_id, blocker_count, has_texture, map_scale.x, map_scale.y])


func _smoke_encounters(game_root: Node) -> void:
	if not game_root.has_method("start_encounter"):
		_fail("GameRoot is missing start_encounter().")
		return

	for encounter_id in ENCOUNTER_IDS:
		_stage("encounter begin id=%s" % encounter_id)
		game_root.call("start_encounter", encounter_id)
		await process_frame
		await process_frame
		await process_frame
		if _timed_out():
			return

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

		var texture_path := _enemy_texture_path(active_battle)
		var expected_texture := str(EXPECTED_ENEMY_TEXTURES.get(encounter_id, ""))
		if expected_texture.is_empty():
			_fail("Encounter %s has no expected texture configured in smoke." % encounter_id)
		elif texture_path != expected_texture:
			_fail("Encounter %s texture mismatch: expected %s, got %s" % [encounter_id, expected_texture, texture_path])
		_stage("encounter end id=%s enemy=%s machine=%s texture=%s" % [encounter_id, active_enemy_id, machine != null, texture_path])

		active_battle.queue_free()
		game_root.set("active_battle", null)
		await process_frame
		await process_frame


func _cleanup(game_root: Node) -> void:
	_stage("cleanup begin")
	if game_root == null or not is_instance_valid(game_root):
		_stage("cleanup skipped game_root_invalid=true")
		return

	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager != null and audio_manager.has_method("stop_all"):
		_stage("cleanup audio_stop begin")
		audio_manager.call("stop_all")
		await process_frame
		_stage("cleanup audio_stop end")

	var active_battle := game_root.get("active_battle") as Node
	if active_battle != null and is_instance_valid(active_battle):
		active_battle.queue_free()

	game_root.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_stage("cleanup end")


func _finish() -> void:
	_stage("quit begin failures=%d" % _failures.size())
	if _failures.is_empty():
		print("SMOKE_OK maps=%d blockers=%d encounters=%d" % [MAP_IDS.size(), MAP_IDS.size(), ENCOUNTER_IDS.size()])
		_stage("quit code=0 elapsed_ms=%d" % _elapsed_ms())
		quit(0)
		return

	for failure in _failures:
		push_error("SMOKE_FAIL %s" % failure)
	print("SMOKE_FAILED failures=%d" % _failures.size())
	_stage("quit code=1 elapsed_ms=%d" % _elapsed_ms())
	quit(1)


func _fail(message: String) -> void:
	_failures.append(message)
	print("SMOKE_FAIL_STAGE last=%s message=%s" % [_last_stage, message])


func _stage(message: String) -> void:
	_last_stage = message
	print("SMOKE_STAGE %s elapsed_ms=%d" % [message, _elapsed_ms()])


func _elapsed_ms() -> int:
	return Time.get_ticks_msec() - _started_ms


func _timed_out() -> bool:
	if _elapsed_ms() <= MAX_ELAPSED_MS:
		return false
	_fail("SMOKE_TIMEOUT stage=%s elapsed_ms=%d max_elapsed_ms=%d" % [_last_stage, _elapsed_ms(), MAX_ELAPSED_MS])
	return true


func _enemy_texture_path(active_battle: Node) -> String:
	var texture_rect := active_battle.get_node_or_null("MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/EnemyVisualRow/EnemyImageFrame/EnemyTexture") as TextureRect
	if texture_rect == null or texture_rect.texture == null:
		return ""
	return texture_rect.texture.resource_path


func _report_viewport(game_root: Node) -> void:
	var viewport_size := root.get_visible_rect().size
	var zoom := Vector2.ONE
	var player := game_root.get("player") as Node
	if player != null:
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			zoom = camera.zoom
	var visible_world := Vector2(
		viewport_size.x / max(0.001, zoom.x),
		viewport_size.y / max(0.001, zoom.y)
	)
	print("VIEWPORT_SMOKE viewport=%dx%d camera_zoom=%.2fx%.2f visible_world=%.0fx%.0f" % [
		int(viewport_size.x),
		int(viewport_size.y),
		zoom.x,
		zoom.y,
		visible_world.x,
		visible_world.y
	])
