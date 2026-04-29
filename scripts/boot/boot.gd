extends Node

const GAME_ROOT_SCENE := "res://scenes/game_root/GameRoot.tscn"

func _ready() -> void:
	DataRegistry.load_all()
	get_tree().change_scene_to_file(GAME_ROOT_SCENE)

