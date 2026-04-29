class_name BattleActorState
extends RefCounted

var id := ""
var display_name := ""
var type := ""
var max_will := 1
var will := 1
var max_obsession := 1
var obsession := 1
var seal_layers: Array = []
var revealed_layers := 0
var skills: Array = []
var intent_cycle: Array = []
var statuses: Dictionary = {}
var metadata: Dictionary = {}


static func from_enemy_data(data: Dictionary) -> BattleActorState:
	var actor := BattleActorState.new()
	actor.metadata = data.duplicate(true)
	actor.id = str(data.get("id", ""))
	actor.display_name = str(data.get("display_name", actor.id))
	actor.type = str(data.get("type", "enemy"))
	actor.max_will = max(1, int(data.get("will", data.get("obsession", 1))))
	actor.will = actor.max_will
	actor.max_obsession = max(1, int(data.get("obsession", actor.max_will)))
	actor.obsession = actor.max_obsession

	var raw_layers = data.get("seal_layers", [])
	if typeof(raw_layers) == TYPE_ARRAY:
		actor.seal_layers = raw_layers.duplicate(true)

	var raw_skills = data.get("skills", [])
	if typeof(raw_skills) == TYPE_ARRAY:
		actor.skills = raw_skills.duplicate(true)

	var raw_intents = data.get("intent_cycle", [])
	if typeof(raw_intents) == TYPE_ARRAY:
		actor.intent_cycle = raw_intents.duplicate(true)

	return actor


func all_seals_revealed() -> bool:
	return revealed_layers >= seal_layers.size()


func current_seal_layer() -> Dictionary:
	if all_seals_revealed():
		return {}
	var layer = seal_layers[revealed_layers]
	if typeof(layer) != TYPE_DICTIONARY:
		return {}
	return layer


func last_revealed_layer() -> Dictionary:
	if revealed_layers <= 0 or seal_layers.is_empty():
		return {}
	var layer = seal_layers[revealed_layers - 1]
	if typeof(layer) != TYPE_DICTIONARY:
		return {}
	return layer


func reveal_current_layer() -> Dictionary:
	var layer := current_seal_layer()
	if layer.is_empty():
		return {}
	revealed_layers += 1
	return layer


func add_status(status_id: String, turns: int = 1) -> void:
	if turns <= 0:
		statuses.erase(status_id)
		return
	statuses[status_id] = max(int(statuses.get(status_id, 0)), turns)


func remove_status(status_id: String) -> void:
	statuses.erase(status_id)


func has_status(status_id: String) -> bool:
	return statuses.has(status_id)


func tick_statuses() -> void:
	for status_id in statuses.keys():
		var turns := int(statuses[status_id])
		if turns >= 999:
			continue
		turns -= 1
		if turns <= 0:
			statuses.erase(status_id)
		else:
			statuses[status_id] = turns


func damage_obsession(amount: int) -> void:
	obsession = max(0, obsession - max(0, amount))

