class_name NPCInteractable
extends Interactable

@export var npc_id := ""
@export var display_name := ""

const NPC_COLORS := {
	"qi": Color(0.92, 0.78, 0.28, 0.95),
	"umbrella_shop_owner": Color(0.35, 0.58, 0.82, 0.95),
	"rain_counting_child": Color(0.45, 0.76, 0.58, 0.95),
	"linmo": Color(0.88, 0.55, 0.56, 0.95),
	"wenheng": Color(0.74, 0.68, 0.58, 0.95),
	"young_wenheng": Color(0.62, 0.72, 0.9, 0.9),
	"uncle_liang": Color(0.52, 0.5, 0.7, 0.95),
}

const NPC_TEXTURES := {
	"wenheng": "res://assets/sprites/characters/npc_roster/npc-1.png",
	"young_wenheng": "res://assets/sprites/characters/npc_roster/npc-1.png",
	"linmo": "res://assets/sprites/characters/npc_roster/npc-2.png",
	"uncle_liang": "res://assets/sprites/characters/npc_roster/npc-3.png",
	"umbrella_shop_owner": "res://assets/sprites/characters/npc_roster/npc-4.png",
	"rain_counting_child": "res://assets/sprites/characters/npc_roster/npc-5.png",
	"qi": "res://assets/sprites/characters/npc_roster/npc-6.png",
}

@onready var body: Polygon2D = get_node_or_null("Body") as Polygon2D
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var name_label: Label = get_node_or_null("NameLabel") as Label


func _ready() -> void:
	super._ready()
	_refresh_visuals()


func configure(instance_data: Dictionary, npc_def: Dictionary) -> void:
	npc_id = str(instance_data.get("npc_id", ""))
	display_name = str(npc_def.get("display_name", npc_id))
	dialogue_id = str(instance_data.get("dialogue_id", ""))
	dialogue_ids = _string_array(instance_data.get("dialogue_ids", []))
	if dialogue_ids.is_empty() and not dialogue_id.strip_edges().is_empty():
		dialogue_ids.append(dialogue_id)
	prompt_text = display_name
	required_actor_group = "player"
	required_flags = _string_array(instance_data.get("required_flags", []))
	blocked_by_flags = _string_array(instance_data.get("blocked_by_flags", []))
	_refresh_visuals()


func _refresh_visuals() -> void:
	if name_label != null:
		name_label.text = display_name if not display_name.strip_edges().is_empty() else npc_id
	if body != null:
		body.color = NPC_COLORS.get(npc_id, Color(0.8, 0.8, 0.8, 0.95))
	if sprite == null:
		return
	var texture := _load_npc_texture(npc_id)
	sprite.texture = texture
	sprite.visible = texture != null
	if body != null:
		body.visible = texture == null


func _load_npc_texture(id: String) -> Texture2D:
	var path := str(NPC_TEXTURES.get(id, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	if loaded is Texture2D:
		return loaded
	return null
