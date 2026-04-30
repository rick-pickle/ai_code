class_name DialogueLayer
extends CanvasLayer

signal dialogue_started(dialogue_id: String)
signal dialogue_line_changed(dialogue_id: String, line_index: int, line: Dictionary)
signal dialogue_finished(dialogue_id: String, applied_effects: Array)
signal dialogue_choice_selected(dialogue_id: String, choice_index: int, choice: Dictionary)

const DialogueRuntimeScript := preload("res://scripts/dialogue/dialogue_runtime.gd")
const RainlampThemeScript := preload("res://scripts/ui/rainlamp_theme.gd")

@export var advance_actions: Array[StringName] = [&"ui_accept", &"interact"]
@export var speaker_names: Dictionary = {
	"acheng": "阿澄",
	"qi": "祈",
	"wenheng": "温衡",
	"young_wenheng": "年轻的温衡",
	"linmo": "林茉",
	"umbrella_shop_owner": "纸伞铺老板",
	"rain_counting_child": "数雨点的小孩",
	"uncle_liang": "梁叔",
	"mailbox_echo": "信箱回声",
	"return_letter": "无址回信",
	"system": "系统",
}
@export var portrait_paths: Dictionary = {}

@onready var root: Control = $Root
@onready var dialog_box: PanelContainer = $Root/DialogBox
@onready var portrait_frame: PanelContainer = $Root/DialogBox/Margin/Content/Header/PortraitFrame
@onready var stamp_label: Label = $Root/DialogBox/Margin/Content/Header/TitleStack/StampLabel
@onready var speaker_label: Label = $Root/DialogBox/Margin/Content/Header/TitleStack/SpeakerLabel
@onready var portrait_texture: TextureRect = $Root/DialogBox/Margin/Content/Header/PortraitFrame/PortraitTexture
@onready var portrait_placeholder: Label = $Root/DialogBox/Margin/Content/Header/PortraitFrame/PortraitPlaceholder
@onready var dialogue_text: Label = $Root/DialogBox/Margin/Content/DialogueText
@onready var choices_box: VBoxContainer = $Root/DialogBox/Margin/Content/Choices
@onready var continue_button: Button = $Root/DialogBox/Margin/Content/Footer/ContinueButton

var _runtime: DialogueRuntime
var _choices_active := false


func _ready() -> void:
	add_to_group("dialogue_layer")
	root.visible = false
	_apply_theme()
	_ensure_runtime()
	continue_button.pressed.connect(_advance)


func _unhandled_input(event: InputEvent) -> void:
	if not root.visible or _runtime == null or not _runtime.is_running:
		return

	for action in advance_actions:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			if not _choices_active:
				_advance()
			return


func start_dialogue(dialogue_id: String) -> bool:
	_ensure_runtime()
	return _runtime.start(dialogue_id)


func is_dialogue_open() -> bool:
	return root.visible and _runtime != null and _runtime.is_running


func cancel_dialogue() -> void:
	if _runtime != null:
		_runtime.cancel()


func _apply_theme() -> void:
	dialog_box.add_theme_stylebox_override("panel", RainlampThemeScript.panel_style())
	portrait_frame.add_theme_stylebox_override("panel", RainlampThemeScript.inset_style())
	RainlampThemeScript.apply_label(stamp_label, RainlampThemeScript.SEAL_RED_DARK)
	RainlampThemeScript.apply_label(speaker_label)
	RainlampThemeScript.apply_label(portrait_placeholder, RainlampThemeScript.MUTED_INK)
	RainlampThemeScript.apply_label(dialogue_text)
	stamp_label.add_theme_font_size_override("font_size", 10)
	speaker_label.add_theme_font_size_override("font_size", 15)
	dialogue_text.add_theme_font_size_override("font_size", 13)
	portrait_placeholder.add_theme_font_size_override("font_size", 18)
	RainlampThemeScript.apply_button(continue_button, true)


func _ensure_runtime() -> void:
	if _runtime != null:
		return

	_runtime = DialogueRuntimeScript.new()
	_runtime.name = "DialogueRuntime"
	add_child(_runtime)
	_runtime.dialogue_started.connect(_on_dialogue_started)
	_runtime.dialogue_line_changed.connect(_on_dialogue_line_changed)
	_runtime.dialogue_choices_requested.connect(_on_choices_requested)
	_runtime.dialogue_choice_selected.connect(_on_choice_selected)
	_runtime.dialogue_finished.connect(_on_dialogue_finished)
	_runtime.dialogue_cancelled.connect(_on_dialogue_cancelled)
	_runtime.dialogue_failed.connect(_on_dialogue_failed)


func _advance() -> void:
	if _runtime != null:
		_runtime.advance()


func _on_dialogue_started(dialogue_id: String, _dialogue: Dictionary) -> void:
	root.visible = true
	_choices_active = false
	_clear_choices()
	dialogue_started.emit(dialogue_id)


func _on_dialogue_line_changed(dialogue_id: String, line_index: int, line: Dictionary) -> void:
	_choices_active = false
	_clear_choices()
	_show_line(line)
	_play_dialogue_advance_sfx()
	continue_button.visible = true
	continue_button.disabled = false
	continue_button.call_deferred("grab_focus")
	dialogue_line_changed.emit(dialogue_id, line_index, line)


func _on_choices_requested(_dialogue_id: String, choices: Array) -> void:
	_choices_active = true
	continue_button.visible = false
	_clear_choices()

	for index in range(choices.size()):
		var choice := _as_dictionary(choices[index])
		var button := Button.new()
		button.text = _choice_text(choice, index)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		RainlampThemeScript.apply_button(button)
		button.pressed.connect(_on_choice_button_pressed.bind(index))
		choices_box.add_child(button)
		if index == 0:
			button.call_deferred("grab_focus")


func _on_choice_button_pressed(choice_index: int) -> void:
	if _runtime != null:
		_runtime.choose(choice_index)


func _on_choice_selected(dialogue_id: String, choice_index: int, choice: Dictionary) -> void:
	_play_dialogue_advance_sfx()
	dialogue_choice_selected.emit(dialogue_id, choice_index, choice)


func _on_dialogue_finished(dialogue_id: String, applied_effects: Array) -> void:
	root.visible = false
	_choices_active = false
	_clear_choices()
	dialogue_finished.emit(dialogue_id, applied_effects)


func _on_dialogue_cancelled(_dialogue_id: String) -> void:
	root.visible = false
	_choices_active = false
	_clear_choices()


func _on_dialogue_failed(dialogue_id: String, reason: String) -> void:
	root.visible = false
	_choices_active = false
	_clear_choices()
	push_warning("对话无法开始：%s，%s" % [dialogue_id, reason])


func _show_line(line: Dictionary) -> void:
	var speaker_id := str(line.get("speaker", ""))
	var speaker_text := _speaker_name(speaker_id)
	speaker_label.text = speaker_text
	dialogue_text.text = str(line.get("text", ""))
	_show_portrait(str(line.get("portrait", "")), speaker_id, speaker_text)


func _show_portrait(portrait_id: String, speaker_id: String, speaker_text: String) -> void:
	var texture := _load_portrait(portrait_id)
	if texture == null:
		texture = _load_portrait(speaker_id)
	portrait_texture.texture = texture
	portrait_texture.visible = texture != null
	portrait_placeholder.visible = texture == null
	if texture == null:
		portrait_placeholder.text = speaker_text.substr(0, 1) if not speaker_text.is_empty() else "像"


func _load_portrait(portrait_id: String) -> Texture2D:
	var trimmed_id := portrait_id.strip_edges()
	if trimmed_id.is_empty():
		return null

	if portrait_paths.has(trimmed_id):
		var configured: Resource = load(str(portrait_paths[trimmed_id]))
		if configured is Texture2D:
			return configured

	for extension in ["png", "webp", "jpg", "jpeg"]:
		var path := "res://assets/portraits/%s.%s" % [trimmed_id, extension]
		if ResourceLoader.exists(path):
			var loaded: Resource = load(path)
			if loaded is Texture2D:
				return loaded

	return null


func _speaker_name(speaker_id: String) -> String:
	var trimmed_id := speaker_id.strip_edges()
	if trimmed_id.is_empty():
		return "旁白"
	return str(speaker_names.get(trimmed_id, "？？？"))


func _choice_text(choice: Dictionary, index: int) -> String:
	var text := str(choice.get("text", choice.get("label", ""))).strip_edges()
	if text.is_empty():
		text = "选项 %d" % (index + 1)
	return text


func _clear_choices() -> void:
	for child in choices_box.get_children():
		child.queue_free()


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _play_dialogue_advance_sfx() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_sfx"):
		audio.play_sfx("dialogue_advance", -12.0)
