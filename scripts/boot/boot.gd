extends Node

const GAME_ROOT_SCENE := "res://scenes/game_root/GameRoot.tscn"

func _ready() -> void:
	DataRegistry.load_all()
	_go_to_game_root.call_deferred()


func _go_to_game_root() -> void:
	get_tree().change_scene_to_file(GAME_ROOT_SCENE)
