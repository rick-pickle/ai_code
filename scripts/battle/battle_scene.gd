extends Control

signal battle_finished(encounter_id: String, victory: bool, reward_flags: Array)

const BattleStateMachineScript := preload("res://scripts/battle/battle_state_machine.gd")
const RainlampThemeScript := preload("res://scripts/ui/rainlamp_theme.gd")

const MIN_SIDE_MARGIN := 10.0
const MAX_BATTLE_WIDTH := 1280.0

@export var auto_start_debug := true
@export var headless_direct_scene_auto_quit := true
@export var debug_encounter_id := "enc_tutorial_wet_paper"
@export var debug_enemy_id := "enemy_wet_paper_echo"
@export var enemy_image_paths: Dictionary = {
	"enemy_return_letter": "res://assets/sprites/enemies/return_letter_idle_3x3/idle-1.png",
	"enemy_wet_paper_echo": "res://assets/sprites/enemies/wet_paper_echo/wet_paper_echo.png",
	"enemy_bridge_lamp_shadow": "res://assets/sprites/enemies/bridge_lamp_shadow/bridge_lamp_shadow.png",
}

var machine: RefCounted
var command_buttons: Dictionary = {}
var active_encounter_id := ""
var active_enemy_id := ""
var victory_flags_applied := false
var result_sfx_played := false
var last_phase_key := ""
var last_tutorial_hint := ""
var last_enemy_obsession := -1
var last_revealed_layers := -1
var last_party_will := -1

@onready var margin_container: MarginContainer = $MarginContainer
@onready var encounter_label: Label = $MarginContainer/BattleLayout/Header/EncounterLabel
@onready var phase_label: Label = $MarginContainer/BattleLayout/Header/PhaseLabel
@onready var restart_button: Button = $MarginContainer/BattleLayout/Header/RestartButton
@onready var close_button: Button = $MarginContainer/BattleLayout/Header/CloseButton
@onready var body: HBoxContainer = $MarginContainer/BattleLayout/Body
@onready var party_panel: PanelContainer = $MarginContainer/BattleLayout/Body/PartyPanel
@onready var party_title: Label = $MarginContainer/BattleLayout/Body/PartyPanel/PartyBox/PartyTitle
@onready var party_stats_label: Label = $MarginContainer/BattleLayout/Body/PartyPanel/PartyBox/PartyStatsLabel
@onready var enemy_panel: PanelContainer = $MarginContainer/BattleLayout/Body/EnemyPanel
@onready var enemy_title: Label = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/EnemyTitle
@onready var enemy_image_frame: PanelContainer = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/EnemyVisualRow/EnemyImageFrame
@onready var enemy_texture: TextureRect = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/EnemyVisualRow/EnemyImageFrame/EnemyTexture
@onready var enemy_stats_label: Label = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/EnemyVisualRow/EnemyStatsLabel
@onready var seal_panel: PanelContainer = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/SealPanel
@onready var seal_label: Label = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/SealPanel/SealLabel
@onready var intent_label: Label = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/IntentLabel
@onready var result_label: Label = $MarginContainer/BattleLayout/Body/EnemyPanel/EnemyBox/ResultLabel
@onready var log_panel: PanelContainer = $MarginContainer/BattleLayout/LogPanel
@onready var log_label: RichTextLabel = $MarginContainer/BattleLayout/LogPanel/LogLabel
@onready var feedback_panel: PanelContainer = $MarginContainer/BattleLayout/FeedbackPanel
@onready var feedback_label: Label = $MarginContainer/BattleLayout/FeedbackPanel/FeedbackLabel
@onready var command_panel: PanelContainer = $MarginContainer/BattleLayout/CommandPanel
@onready var command_title: Label = $MarginContainer/BattleLayout/CommandPanel/CommandBox/CommandTitle
@onready var commands: GridContainer = $MarginContainer/BattleLayout/CommandPanel/CommandBox/Commands


func _ready() -> void:
	print("BATTLE_STAGE ready auto_start_debug=%s headless=%s direct_scene=%s" % [auto_start_debug, _is_headless(), _is_direct_scene_root()])
	_apply_responsive_layout()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	command_buttons = {
		"open_seal": $MarginContainer/BattleLayout/CommandPanel/CommandBox/Commands/OpenSealButton,
		"archive_seal": $MarginContainer/BattleLayout/CommandPanel/CommandBox/Commands/ArchiveSealButton,
		"return_to_sender": $MarginContainer/BattleLayout/CommandPanel/CommandBox/Commands/ReturnButton,
		"send_letter": $MarginContainer/BattleLayout/CommandPanel/CommandBox/Commands/SendButton,
		"see_through": $MarginContainer/BattleLayout/CommandPanel/CommandBox/Commands/SeeButton,
		"lamplight": $MarginContainer/BattleLayout/CommandPanel/CommandBox/Commands/LamplightButton
	}
	_apply_theme()

	for skill_id in command_buttons.keys():
		var button: Button = command_buttons[skill_id]
		button.pressed.connect(_on_command_pressed.bind(str(skill_id)))
	restart_button.pressed.connect(_on_restart_pressed)
	close_button.pressed.connect(_on_close_pressed)
	close_button.visible = false

	_ensure_registry_loaded()
	if auto_start_debug:
		start_encounter(debug_encounter_id)
	if headless_direct_scene_auto_quit and _is_headless() and _is_direct_scene_root():
		_headless_quit_after_debug_start.call_deferred()


func _apply_responsive_layout() -> void:
	if margin_container == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var side_margin: float = maxf(MIN_SIDE_MARGIN, floor((viewport_size.x - MAX_BATTLE_WIDTH) * 0.5))
	margin_container.add_theme_constant_override("margin_left", int(side_margin))
	margin_container.add_theme_constant_override("margin_right", int(side_margin))
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)

	var tall_window := viewport_size.y >= 720.0
	body.custom_minimum_size = Vector2(0, 360 if tall_window else 282)
	enemy_image_frame.custom_minimum_size = Vector2(196, 196) if tall_window else Vector2(148, 148)
	seal_panel.custom_minimum_size = Vector2(500, 76) if tall_window else Vector2(420, 58)
	log_panel.custom_minimum_size = Vector2(0, 92) if tall_window else Vector2(0, 62)
	feedback_panel.custom_minimum_size = Vector2(0, 40) if tall_window else Vector2(0, 30)
	command_panel.custom_minimum_size = Vector2(0, 104) if tall_window else Vector2(0, 78)
	commands.custom_minimum_size = Vector2(0, 84) if tall_window else Vector2(0, 52)


func start_encounter(encounter_id: String) -> void:
	print("BATTLE_STAGE start_encounter begin id=%s" % encounter_id)
	_ensure_registry_loaded()
	var encounter := _load_encounter(encounter_id)
	if encounter.is_empty():
		_append_log("找不到遭遇：%s。" % encounter_id)
		if debug_enemy_id != "":
			start_enemy(debug_enemy_id)
		return

	var enemies: Variant = encounter.get("enemies", [])
	if typeof(enemies) != TYPE_ARRAY or enemies.is_empty():
		_append_log("遭遇没有配置敌人：%s。" % encounter_id)
		return

	active_encounter_id = encounter_id
	start_enemy(str(enemies[0]), encounter)
	print("BATTLE_STAGE start_encounter end id=%s enemy=%s" % [encounter_id, active_enemy_id])


func start_enemy(enemy_id: String, encounter_data: Dictionary = {}) -> void:
	print("BATTLE_STAGE start_enemy begin id=%s" % enemy_id)
	_ensure_registry_loaded()
	var enemy_data := _load_enemy(enemy_id)
	if enemy_data.is_empty():
		_append_log("找不到敌人：%s。" % enemy_id)
		return

	active_enemy_id = enemy_id
	victory_flags_applied = false
	result_sfx_played = false
	last_phase_key = ""
	last_tutorial_hint = ""
	last_enemy_obsession = -1
	last_revealed_layers = -1
	last_party_will = -1
	close_button.visible = false
	result_label.text = ""
	feedback_label.text = ""
	log_label.clear()
	_apply_enemy_texture(enemy_id, enemy_data)
	_play_encounter_intro_sfx(enemy_id)

	machine = BattleStateMachineScript.new()
	machine.logged.connect(_append_log)
	machine.changed.connect(_on_battle_changed)
	machine.setup(enemy_data, _load_skills(), encounter_data)
	print("BATTLE_STAGE start_enemy end id=%s machine=yes" % enemy_id)


func _on_command_pressed(skill_id: String) -> void:
	if machine == null:
		return
	var accepted: bool = machine.use_skill(skill_id)
	if accepted:
		_play_skill_sfx(skill_id)
		_pulse_command_button(skill_id)
		var snapshot: Dictionary = machine.snapshot()
		var phase_key := str(snapshot.get("phase_key", ""))
		if phase_key != "victory" and phase_key != "defeat":
			_show_skill_feedback(skill_id)
			_show_tutorial_hint(snapshot, true)


func _on_restart_pressed() -> void:
	if active_encounter_id != "":
		start_encounter(active_encounter_id)
	elif active_enemy_id != "":
		start_enemy(active_enemy_id)


func _on_close_pressed() -> void:
	var victory := false
	var rewards: Array = []
	if machine != null and machine.has_method("snapshot"):
		var snapshot: Dictionary = machine.snapshot()
		victory = str(snapshot.get("phase_key", "")) == "victory"
		var raw_rewards: Variant = snapshot.get("reward_flags", [])
		if typeof(raw_rewards) == TYPE_ARRAY:
			rewards = raw_rewards
	battle_finished.emit(active_encounter_id, victory, rewards)
	queue_free()


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
	seal_label.text = "封缄：\n%s" % _join_lines(snapshot.get("seal_lines", []), "无封缄")
	intent_label.text = "意图：%s" % str(snapshot.get("intent_text", ""))

	var commands: Variant = snapshot.get("commands", [])
	if typeof(commands) == TYPE_ARRAY:
		for command in commands:
			if typeof(command) != TYPE_DICTIONARY:
				continue
			var command_data: Dictionary = command
			var skill_id := str(command_data.get("id", ""))
			if not command_buttons.has(skill_id):
				continue
			var button: Button = command_buttons[skill_id]
			button.text = "%s %d" % [str(command_data.get("label", skill_id)), int(command_data.get("cost", 0))]
			button.disabled = bool(command_data.get("disabled", true))

	var phase_key := str(snapshot.get("phase_key", ""))
	_apply_delta_feedback(snapshot, phase_key)
	if phase_key == "victory" and not victory_flags_applied:
		victory_flags_applied = true
		_apply_reward_flags(snapshot.get("reward_flags", []))

	if phase_key != last_phase_key:
		_on_phase_changed(phase_key)
		last_phase_key = phase_key

	close_button.visible = phase_key == "victory" or phase_key == "defeat"
	close_button.text = "返回地图" if phase_key == "victory" else "离开战斗"
	result_label.text = _result_text(phase_key)

	_show_tutorial_hint(snapshot, false)


func _append_log(message: String) -> void:
	if log_label == null:
		return
	log_label.append_text("%s\n" % message)
	log_label.scroll_to_line(max(0, log_label.get_line_count() - 1))


func _apply_reward_flags(flags: Variant) -> void:
	if typeof(flags) != TYPE_ARRAY:
		return
	var game_state := get_node_or_null("/root/GameState")
	for flag in flags:
		var flag_id := str(flag)
		if game_state != null and game_state.has_method("set_flag"):
			game_state.set_flag(flag_id, true)
		_append_log("已设置标记：%s。" % flag_id)


func _apply_theme() -> void:
	party_panel.add_theme_stylebox_override("panel", RainlampThemeScript.panel_style(Color(0.86, 0.77, 0.58), RainlampThemeScript.PAPER_DARK, 2, 4))
	enemy_panel.add_theme_stylebox_override("panel", RainlampThemeScript.panel_style(Color(0.96, 0.88, 0.66), RainlampThemeScript.SEAL_RED_DARK, 2, 4))
	enemy_image_frame.add_theme_stylebox_override("panel", RainlampThemeScript.inset_style(Color(0.74, 0.62, 0.43), RainlampThemeScript.SEAL_RED_DARK))
	seal_panel.add_theme_stylebox_override("panel", RainlampThemeScript.inset_style(Color(0.90, 0.73, 0.49), RainlampThemeScript.SEAL_RED_DARK))
	log_panel.add_theme_stylebox_override("panel", RainlampThemeScript.inset_style(Color(0.93, 0.84, 0.66), RainlampThemeScript.PAPER_DARK))
	feedback_panel.add_theme_stylebox_override("panel", RainlampThemeScript.inset_style(Color(0.97, 0.84, 0.56), RainlampThemeScript.SEAL_RED_DARK))
	command_panel.add_theme_stylebox_override("panel", RainlampThemeScript.panel_style(Color(0.82, 0.69, 0.48), RainlampThemeScript.SEAL_RED_DARK, 2, 4))

	for label in [encounter_label, phase_label, party_title, party_stats_label, enemy_title, enemy_stats_label, seal_label, intent_label, command_title]:
		var typed_label: Label = label
		RainlampThemeScript.apply_label(typed_label)
		typed_label.add_theme_font_size_override("font_size", 11)

	party_title.add_theme_color_override("font_color", RainlampThemeScript.SEAL_RED_DARK)
	enemy_title.add_theme_color_override("font_color", RainlampThemeScript.SEAL_RED_DARK)
	command_title.add_theme_color_override("font_color", RainlampThemeScript.SEAL_RED_DARK)
	result_label.add_theme_color_override("font_color", RainlampThemeScript.SEAL_RED)
	result_label.add_theme_font_size_override("font_size", 12)
	RainlampThemeScript.apply_label(feedback_label, RainlampThemeScript.SEAL_RED_DARK)
	feedback_label.add_theme_font_size_override("font_size", 11)
	RainlampThemeScript.apply_rich_text(log_label)

	for skill_id in command_buttons.keys():
		var command_button: Button = command_buttons[skill_id]
		RainlampThemeScript.apply_button(command_button, skill_id == "send_letter")
	RainlampThemeScript.apply_button(restart_button)
	RainlampThemeScript.apply_button(close_button, true)


func _apply_enemy_texture(enemy_id: String, enemy_data: Dictionary) -> void:
	var texture := _load_enemy_texture(enemy_id, enemy_data)
	enemy_texture.texture = texture
	enemy_texture.visible = texture != null


func _load_enemy_texture(enemy_id: String, enemy_data: Dictionary) -> Texture2D:
	var configured_path := ""
	if enemy_image_paths.has(enemy_id):
		configured_path = str(enemy_image_paths[enemy_id])
	else:
		for key in ["image_path", "texture_path", "sprite_path", "visual_path"]:
			if enemy_data.has(key):
				configured_path = str(enemy_data[key])
				break

	if configured_path.is_empty() or not ResourceLoader.exists(configured_path):
		return null

	var loaded: Resource = load(configured_path)
	if loaded is Texture2D:
		return loaded
	return null


func _result_text(phase_key: String) -> String:
	if phase_key == "victory":
		return "封缄已释，回信归档"
	if phase_key == "defeat":
		return "信纸浸透，灯火暂熄"
	return ""


func _show_skill_feedback(skill_id: String) -> void:
	feedback_label.text = _skill_feedback_text(skill_id)
	_animate_enemy_action(Color(1.0, 0.88, 0.62, 1.0))
	_flash_feedback_panel()


func _show_tutorial_hint(snapshot: Dictionary, append_to_current: bool) -> void:
	if str(snapshot.get("phase_key", "")) != "player_turn":
		return
	var tutorial_hint := str(snapshot.get("tutorial_hint", ""))
	if tutorial_hint.strip_edges().is_empty():
		return
	if not append_to_current and not feedback_label.text.strip_edges().is_empty() and tutorial_hint == last_tutorial_hint:
		return

	var hint_text := "教学：%s" % tutorial_hint
	if append_to_current and not feedback_label.text.strip_edges().is_empty():
		feedback_label.text = "%s  %s" % [feedback_label.text, hint_text]
	else:
		feedback_label.text = hint_text
	last_tutorial_hint = tutorial_hint


func _skill_feedback_text(skill_id: String) -> String:
	match skill_id:
		"open_seal":
			return "纸边掀起，封泥松动。"
		"archive_seal":
			return "封蜡压平，回声被收入旧档。"
		"return_to_sender":
			return "退回戳印落下，谎言沿雨声折返。"
		"send_letter":
			return "信被寄出，灯下只剩湿亮的邮路。"
		"see_through":
			return "灯芯一亮，敌意露出字脚。"
		"lamplight":
			return "添灯后，信纸边缘重新泛暖。"
		_:
			return ""


func _on_phase_changed(phase_key: String) -> void:
	if result_sfx_played:
		return
	if phase_key == "victory":
		result_sfx_played = true
		feedback_label.text = "胜利：回信归档，雨声退到窗外。"
		_animate_battle_result(true)
		_flash_feedback_panel()
		_play_sfx("victory")
	elif phase_key == "defeat":
		result_sfx_played = true
		feedback_label.text = "失败：墨迹漫开，灯火暂熄。"
		_animate_battle_result(false)
		_flash_feedback_panel()
		_play_sfx("defeat")


func _play_encounter_intro_sfx(enemy_id: String) -> void:
	if enemy_id == "enemy_return_letter":
		_play_sfx("boss_appear", -6.0)


func _play_skill_sfx(skill_id: String) -> void:
	var audio := _audio_manager()
	if audio != null and audio.has_method("play_skill"):
		audio.play_skill(skill_id)


func _play_sfx(sound_id: String, volume_db: float = -8.0) -> void:
	var audio := _audio_manager()
	if audio != null and audio.has_method("play_sfx"):
		audio.play_sfx(sound_id, volume_db)


func _audio_manager() -> Node:
	return get_node_or_null("/root/AudioManager")


func _apply_delta_feedback(snapshot: Dictionary, phase_key: String) -> void:
	var enemy_obsession := int(snapshot.get("enemy_obsession", 0))
	var revealed_layers := int(snapshot.get("revealed_layers", 0))
	var party_will := int(snapshot.get("acheng_will", 0)) + int(snapshot.get("qi_will", 0))
	if last_enemy_obsession >= 0 and enemy_obsession < last_enemy_obsession:
		_animate_enemy_hit()
	if last_revealed_layers >= 0 and revealed_layers > last_revealed_layers:
		_animate_seal_break()
	if last_party_will >= 0 and party_will < last_party_will and phase_key != "victory" and phase_key != "defeat":
		_animate_party_damage()
	last_enemy_obsession = enemy_obsession
	last_revealed_layers = revealed_layers
	last_party_will = party_will


func _pulse_command_button(skill_id: String) -> void:
	if not command_buttons.has(skill_id):
		return
	var button: Button = command_buttons[skill_id]
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.04, 1.04), 0.05)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)


func _prepare_control_pivot(control: Control) -> void:
	if control == null:
		return
	control.pivot_offset = control.size * 0.5


func _animate_enemy_action(tint: Color) -> void:
	if enemy_texture == null:
		return
	_prepare_control_pivot(enemy_texture)
	var tween := create_tween()
	tween.tween_property(enemy_texture, "scale", Vector2(1.08, 1.08), 0.06)
	tween.parallel().tween_property(enemy_texture, "modulate", tint, 0.06)
	tween.tween_property(enemy_texture, "scale", Vector2.ONE, 0.14)
	tween.parallel().tween_property(enemy_texture, "modulate", Color.WHITE, 0.14)


func _animate_enemy_hit() -> void:
	if enemy_texture == null:
		return
	_prepare_control_pivot(enemy_texture)
	var original_position := enemy_texture.position
	var tween := create_tween()
	tween.tween_property(enemy_texture, "position", original_position + Vector2(-5, 0), 0.035)
	tween.parallel().tween_property(enemy_texture, "modulate", Color(1.0, 0.62, 0.48, 1.0), 0.035)
	tween.tween_property(enemy_texture, "position", original_position + Vector2(5, 0), 0.045)
	tween.tween_property(enemy_texture, "position", original_position, 0.055)
	tween.parallel().tween_property(enemy_texture, "modulate", Color.WHITE, 0.08)


func _animate_seal_break() -> void:
	_prepare_control_pivot(seal_panel)
	var tween := create_tween()
	tween.tween_property(seal_panel, "scale", Vector2(1.015, 1.08), 0.06)
	tween.parallel().tween_property(seal_panel, "modulate", Color(1.0, 0.78, 0.50, 1.0), 0.06)
	tween.tween_property(seal_panel, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(seal_panel, "modulate", Color.WHITE, 0.18)
	_play_sfx("open_seal", -9.0)


func _animate_party_damage() -> void:
	var tween := create_tween()
	tween.tween_property(party_panel, "modulate", Color(1.0, 0.55, 0.48, 1.0), 0.06)
	tween.tween_property(party_panel, "modulate", Color.WHITE, 0.16)


func _animate_battle_result(victory: bool) -> void:
	_prepare_control_pivot(result_label)
	var tint := Color(0.72, 1.0, 0.82, 1.0) if victory else Color(1.0, 0.45, 0.45, 1.0)
	_animate_enemy_action(tint)
	var tween := create_tween()
	tween.tween_property(result_label, "scale", Vector2(1.08, 1.08), 0.08)
	tween.parallel().tween_property(result_label, "modulate", tint, 0.08)
	tween.tween_property(result_label, "scale", Vector2.ONE, 0.18)
	tween.parallel().tween_property(result_label, "modulate", Color.WHITE, 0.18)


func _flash_feedback_panel() -> void:
	if feedback_panel == null:
		return
	var tween := create_tween()
	tween.tween_property(feedback_panel, "modulate", Color(1.0, 0.92, 0.72, 1.0), 0.06)
	tween.tween_property(feedback_panel, "modulate", Color.WHITE, 0.14)


func _headless_quit_after_debug_start() -> void:
	for frame in range(6):
		await get_tree().process_frame
	var machine_ready := machine != null
	print("BATTLE_SCENE_SMOKE_OK encounter=%s enemy=%s machine=%s" % [active_encounter_id, active_enemy_id, machine_ready])
	get_tree().quit(0)


func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"


func _is_direct_scene_root() -> bool:
	return get_tree() != null and get_tree().current_scene == self


func _ensure_registry_loaded() -> void:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry == null or not registry.has_method("load_all"):
		return
	var enemies: Variant = registry.get("enemies")
	if typeof(enemies) != TYPE_DICTIONARY or enemies.is_empty():
		registry.load_all()


func _load_encounter(encounter_id: String) -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry != null:
		var registry_encounters: Variant = registry.get("encounters")
		if typeof(registry_encounters) == TYPE_DICTIONARY and registry_encounters.has(encounter_id):
			return registry_encounters[encounter_id]
	return _load_collection_file("res://data/encounters/vertical_slice_encounters.json", "encounters").get(encounter_id, {})


func _load_enemy(enemy_id: String) -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry != null:
		var registry_enemies: Variant = registry.get("enemies")
		if typeof(registry_enemies) == TYPE_DICTIONARY and registry_enemies.has(enemy_id):
			return registry_enemies[enemy_id]
	return _load_json_file("res://data/enemies/%s.json" % enemy_id)


func _load_skills() -> Dictionary:
	var registry := get_node_or_null("/root/DataRegistry")
	if registry != null:
		var registry_skills: Variant = registry.get("skills")
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
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid JSON object: %s" % path)
		return {}
	return parsed


func _join_lines(lines: Variant, empty_text: String) -> String:
	if typeof(lines) != TYPE_ARRAY or lines.is_empty():
		return empty_text
	var text := ""
	for line in lines:
		if text != "":
			text += "\n"
		text += str(line)
	return text
