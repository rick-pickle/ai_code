extends Node2D

@export var map_id: String
@export var display_name: String

func get_spawn_point(spawn_id: String = "player_start") -> Vector2:
	var spawns := $Spawns if has_node("Spawns") else null
	if spawns == null:
		return Vector2.ZERO
	for child in spawns.get_children():
		if child.name == spawn_id:
			return child.global_position
	return Vector2.ZERO

