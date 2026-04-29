extends Control

const BattleStateMachineScript := preload("res://scripts/battle/battle_state_machine.gd")

@export var auto_start_debug := true
@export var debug_encounter_id := "enc_tutorial_wet_paper"
@export var debug_enemy_id := "enemy_wet_paper_echo"

var machine: RefCounted
var command_buttons: Dictionary = {}
var active_encounter_id := ""
var active_enemy_id := ""
var victory_flags_applied := false

@onready var encounter_label: Label = $MarginContainer/BattleLayout/Header/EncounterLabel
@onready var phase_label: Label = $MarginContainer/BattleLayout/Header/PhaseLabel
@onready var restart_button: Button = $MarginContainer/BattleLayout/Header/RestartButton
@onready var party_stats_label: Label = $MarginContainer/BattleLayout/Body/PartyPanel/PartyBox/PartyStatsLabel
@onready var enemy_stats_label: Label = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/EnemyStatsLabel
@onready var seal_label: Label = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/SealLabel
@onready var intent_label: Label = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/IntentLabel
@onready var log_label: RichTextLabel = $MarginContainer/BattleLayout/LogPanel/LogLabel


func _ready() -> void:
	command_buttons = {
		"open_seal": $MarginContainer/BattleLayout/Commands/OpenSealButton,
		"archive_seal": $MarginContainer/BattleLayout/Commands/ArchiveSealButton,
		"return_to_sender": $MarginContainer/BattleLayout/Commands/ReturnButton,
		"send_letter": $MarginContainer/BattleLayout/Commands/SendButton,
		"see_through": $MarginContainer/BattleLayout/Commands/SeeButton,
		"lamplight": $MarginContainer/BattleLayout/Commands/LamplightButton
	}

	for skill_id in command_buttons.keys():
		var button: Button = command_buttons[skill_id]
		button.pressed.connect(_on_command_pressed.bind(str(skill_id)))
	restart_button.pressed.connect(_on_restart_pressed)

	_ensure_registry_loaded()
	if auto_start_debug:
		start_encounter(debug_encounter_id)


func start_encounter(encounter_id: String) -> void:
	_ensure_registry_loaded()
	var encounter := _load_encounter(encounter_id)
	if encounter.is_empty():
		_append_log("找不到遭遇：%s。" % encounter_id)
		if debug_enemy_id != "":
			start_enemy(debug_enemy_id)
		return

	var enemies = encounter.get("enemies", [])
	if typeof(enemies) != TYPE_ARRAY or enemies.is_empty():
		_append_log("遭遇没有配置敌人：%s。" % encounter_id)
		return

	active_encounter_id = encounter_id
	start_enemy(str(enemies[0]), encounter)


func start_enemy(enemy_id: String, encounter_data: Dictionary = {}) -> void:
	_ensure_registry_loaded()
	var enemy_data := _load_enemy(enemy_id)
	if enemy_data.is_empty():
		_append_log("找不到敌人：%s。" % enemy_id)
		return

	active_enemy_id = enemy_id
	victory_flags_applied = false
	log_label.clear()

	machine = BattleStateMachineScript.new()
	machine.logged.connect(_append_log)
	machine.changed.connect(_on_battle_changed)
	machine.setup(enemy_data, _load_skills(), encounter_data)


func _on_command_pressed(skill_id: String) -> void:
	if machine == null:
		return
	machine.use_skill(skill_id)


func _on_restart_pressed() -> void:
	if active_encounter_id != "":
		start_encounter(active_encounter_id)
	elif active_enemy_id != "":
		start_enemy(active_enemy_id)


func _on_battle_changed(snapshot: Dictionary) -> void:
	encounter_label.text = "遭遇：%s  第 %d 回合" % [str(snapshot.get("enemy_name", "")), int(snapshot.get("turn_number", 0))]
	phase_label.text = "阶段：%s" % str(snapshot.get("phase_label", ""))

	var party_statuses := _join_lines(snapshot.get("party_statuses", []), "无")
	party_stats_label.text = "阿澄意志：%d/%d\n祈意志：%d/%d\n灯火值：%d/%d\n雨噪：%d  清明：%d\n状态：%s" % [
		int(snapshot.get("acheng_will", 0)),
		int(snapshot.get("acheng_max_will", 0)),
		int(snapshot.get("qi_will", 0)),
		int(snapshot.get("qi_max_will", 0)),
		int(snapshot.get("lamplight", 0)),
		int(snapshot.get("max_lamplight", 0)),
		int(snapshot.get("rain_noise", 0)),
		int(snapshot.get("clarity", 0)),
		party_statuses
	]

	var enemy_statuses := _join_lines(snapshot.get("enemy_statuses", []), "无")
	enemy_stats_label.text = "%s\n执念：%d/%d\n状态：%s" % [
		str(snapshot.get("enemy_name", "")),
		int(snapshot.get("enemy_obsession", 0)),
		int(snapshot.get("enemy_max_obsession", 0)),
		enemy_statuses
	]
	seal_label.text = _join_lines(snapshot.get("seal_lines", []), "无封缄")
	intent_label.text = "意图：%s" % str(snapshot.get("intent_text", ""))

	for command in snapshot.get("commands", []):
		if typeof(command) != TYPE_DICTIONARY:
			continue
		var skill_id := str(command.get("id", ""))
		var button: Button = command_buttons.get(skill_id)
		if button == null:
			continue
		button.text = "%s %d" % [str(command.get("label", skill_id)), int(command.get("cost", 0))]
		button.disabled = bool(command.get("disabled", true))

	if str(snapshot.get("phase_key", "")) == "victory" and not victory_flags_applied:
		victory_flags_applied = true
		_apply_reward_flags(snapshot.get("reward_flags", []))


func _append_log(message: String) -> void:
	if log_label == null:
		return
	log_label.append_text("%s\n" % message)
	log_label.scroll_to_line(max(0, log_label.get_line_count() - 1))


func _apply_reward_flags(flags) -> void:
	if typeof(flags) != TYPE_ARRAY:
		return
	var game_state := get_node_or_null("/root/GameState")
	for flag in flags:
		var flag_id := str(flag)
		if game_state != null and game_state.has_method("set_flag"):
			game_state.set_flag(flag_id, true)
		_append_log("已设置标记：%s。" % flag_id)


func _ensure_registry_loaded() -> void:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null or not registry.has_method("load_all"):
		return
	var enemies = registry.get("enemies")
	if typeof(enemies) != TYPE_DICTIONARY or enemies.is_empty():
		registry.load_all()


func _load_encounter(encounter_id: String) -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry != null:
		var registry_encounters = registry.get("encounters")
		if typeof(registry_encounters) == TYPE_DICTIONARY and registry_encounters.has(encounter_id):
			return registry_encounters[encounter_id]
	return _load_collection_file("res://data/encounters/vertical_slice_encounters.json", "encounters").get(encounter_id, {})


func _load_enemy(enemy_id: String) -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry != null:
		var registry_enemies = registry.get("enemies")
		if typeof(registry_enemies) == TYPE_DICTIONARY and registry_enemies.has(enemy_id):
			return registry_enemies[enemy_id]
	return _load_json_file("res://data/enemies/%s.json" % enemy_id)


func _load_skills() -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry != null:
		var registry_skills = registry.get("skills")
		if typeof(registry_skills) == TYPE_DICTIONARY and not registry_skills.is_empty():
			return registry_skills
	return _load_collection_file("res://data/skills/core_skills.json", "skills")


func _load_collection_file(path: String, collection_key: String) -> Dictionary:
	var result: Dictionary = {}
	var root := _load_json_file(path)
	for item in root.get(collection_key, []):
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			result[str(item["id"])] = item
	return result


func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing JSON file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid JSON object: %s" % path)
		return {}
	return parsed


func _join_lines(lines, empty_text: String) -> String:
	if typeof(lines) != TYPE_ARRAY or lines.is_empty():
		return empty_text
	var text := ""
	for line in lines:
		if text != "":
			text += "\n"
		text += str(line)
	return text
