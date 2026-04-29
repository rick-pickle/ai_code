extends Node

var flags: Dictionary = {}
var handbook_progress: Dictionary = {}
var current_letter_id := ""

func has_flag(flag_id: String) -> bool:
	return flags.get(flag_id, false)

func set_flag(flag_id: String, value: bool = true) -> void:
	flags[flag_id] = value

func clear_flag(flag_id: String) -> void:
	flags.erase(flag_id)

func set_current_letter(letter_id: String) -> void:
	current_letter_id = letter_id

func set_handbook_progress(entry_id: String, progress: int) -> void:
	handbook_progress[entry_id] = progress

func get_handbook_progress(entry_id: String) -> int:
	return int(handbook_progress.get(entry_id, 0))

