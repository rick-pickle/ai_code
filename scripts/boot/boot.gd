extends Node

const GAME_ROOT_SCENE := "res://scenes/game_root/GameRoot.tscn"
const HEADLESS_BOOT_FRAMES := 8

func _ready() -> void:
	print("BOOT_STAGE ready headless=%s" % _is_headless())
	DataRegistry.load_all()
	if _is_headless():
		_headless_boot_smoke.call_deferred()
		return
	_go_to_game_root.call_deferred()


func _go_to_game_root() -> void:
	print("BOOT_STAGE change_scene begin target=%s" % GAME_ROOT_SCENE)
	get_tree().change_scene_to_file(GAME_ROOT_SCENE)


func _headless_boot_smoke() -> void:
	print("BOOT_STAGE headless_load_game_root begin")
	var packed := load(GAME_ROOT_SCENE) as PackedScene
	if packed == null:
		push_error("BOOT_SMOKE_FAIL missing_game_root=%s" % GAME_ROOT_SCENE)
		get_tree().quit(1)
		return
	var game_root := packed.instantiate()
	if game_root == null:
		push_error("BOOT_SMOKE_FAIL instantiate_game_root")
		get_tree().quit(1)
		return
	add_child(game_root)
	for frame in range(HEADLESS_BOOT_FRAMES):
		await get_tree().process_frame
	var map_id := str(game_root.get("current_map_id"))
	print("BOOT_SMOKE_OK loaded_game_root=true current_map=%s frames=%d" % [map_id, HEADLESS_BOOT_FRAMES])
	game_root.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"
