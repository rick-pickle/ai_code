class_name RainlampTheme
extends RefCounted

const PAPER := Color(0.88, 0.80, 0.64)
const PAPER_LIGHT := Color(0.95, 0.89, 0.74)
const PAPER_DARK := Color(0.72, 0.57, 0.36)
const INK := Color(0.18, 0.12, 0.08)
const MUTED_INK := Color(0.36, 0.27, 0.18)
const SEAL_RED := Color(0.55, 0.12, 0.10)
const SEAL_RED_DARK := Color(0.32, 0.06, 0.05)
const SHADOW := Color(0.09, 0.06, 0.04, 0.45)
const FONT_PATH := "res://assets/fonts/SourceHanSansCN-Normal.ttf"


static func primary_font() -> Font:
	var loaded: Resource = load(FONT_PATH)
	if loaded is Font:
		return loaded
	return null


static func panel_style(bg_color: Color = PAPER, border_color: Color = PAPER_DARK, border_width: int = 2, radius: int = 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = SHADOW
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 2)
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style


static func inset_style(bg_color: Color = PAPER_LIGHT, border_color: Color = PAPER_DARK) -> StyleBoxFlat:
	var style := panel_style(bg_color, border_color, 1, 3)
	style.shadow_size = 0
	style.content_margin_left = 5.0
	style.content_margin_top = 5.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 5.0
	return style


static func button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 6.0
	style.content_margin_top = 3.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 3.0
	return style


static func apply_button(button: Button, accent: bool = false) -> void:
	var normal_bg := SEAL_RED if accent else PAPER_LIGHT
	var hover_bg := Color(0.66, 0.18, 0.15) if accent else Color(0.98, 0.92, 0.76)
	var pressed_bg := SEAL_RED_DARK if accent else Color(0.78, 0.64, 0.42)
	var border := SEAL_RED_DARK if accent else PAPER_DARK
	var font_color := PAPER_LIGHT if accent else INK
	button.add_theme_stylebox_override("normal", button_style(normal_bg, border))
	button.add_theme_stylebox_override("hover", button_style(hover_bg, border))
	button.add_theme_stylebox_override("pressed", button_style(pressed_bg, border))
	button.add_theme_stylebox_override("disabled", button_style(Color(0.55, 0.50, 0.42), Color(0.36, 0.30, 0.22)))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color(0.28, 0.24, 0.20))
	var font := primary_font()
	if font != null:
		button.add_theme_font_override("font", font)
	button.focus_mode = Control.FOCUS_ALL


static func apply_label(label: Label, color: Color = INK) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var font := primary_font()
	if font != null:
		label.add_theme_font_override("font", font)


static func apply_rich_text(label: RichTextLabel) -> void:
	label.add_theme_color_override("default_color", INK)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var font := primary_font()
	if font != null:
		label.add_theme_font_override("normal_font", font)
