class_name BattleStateMachine
extends RefCounted

signal changed(snapshot: Dictionary)
signal logged(message: String)

enum Phase {
	SETUP,
	PLAYER_TURN,
	RESOLVING_COMMAND,
	ENEMY_TURN,
	VICTORY,
	DEFEAT
}

const PLAYER_COMMANDS := [
	"open_seal",
	"archive_seal",
	"return_to_sender",
	"send_letter",
	"see_through",
	"lamplight"
]

const PHASE_KEYS := {
	Phase.SETUP: "setup",
	Phase.PLAYER_TURN: "player_turn",
	Phase.RESOLVING_COMMAND: "resolving_command",
	Phase.ENEMY_TURN: "enemy_turn",
	Phase.VICTORY: "victory",
	Phase.DEFEAT: "defeat"
}

const PHASE_LABELS := {
	Phase.SETUP: "准备中",
	Phase.PLAYER_TURN: "玩家回合",
	Phase.RESOLVING_COMMAND: "指令处理中",
	Phase.ENEMY_TURN: "敌方回合",
	Phase.VICTORY: "投递完成",
	Phase.DEFEAT: "灯火熄灭"
}

const FALLBACK_SKILL_LABELS := {
	"open_seal": "拆封",
	"archive_seal": "封存",
	"return_to_sender": "退回",
	"send_letter": "寄出",
	"see_through": "照见",
	"lamplight": "添灯"
}

const STATUS_LABELS := {
	"wet_words": "湿字",
	"hesitation": "迟疑",
	"bound_by_lie": "被谎言缠住",
	"rain_noise_in_ears": "雨噪入耳",
	"weak_lamplight": "灯火微弱",
	"seen_through": "已照见",
	"clear_mind": "清明",
	"steady_pen": "稳笔",
	"archived": "封存",
	"returned_intent": "退回余势",
	"seal_loosened": "封缄松动",
	"lie_shroud": "谎言护层"
}

var phase := Phase.SETUP
var turn_number := 0
var lamplight := 3
var max_lamplight := 8
var lamplight_recovery := 2
var clarity := 1
var rain_noise := 0

var acheng_max_will := 30
var acheng_will := 30
var qi_max_will := 24
var qi_will := 24
var party_statuses: Dictionary = {}

var enemy: BattleActorState
var skills: Dictionary = {}
var encounter: Dictionary = {}
var current_intent: Dictionary = {}
var intent_index := 0
var intent_visible := false
var reward_flags: Array = []


func setup(enemy_data: Dictionary, skill_data: Dictionary, encounter_data: Dictionary = {}) -> void:
	phase = Phase.SETUP
	turn_number = 0
	lamplight = 3
	max_lamplight = 8
	lamplight_recovery = 2
	clarity = 1
	rain_noise = 0
	acheng_will = acheng_max_will
	qi_will = qi_max_will
	party_statuses.clear()
	current_intent.clear()
	intent_index = 0
	intent_visible = false
	reward_flags.clear()
	skills = skill_data.duplicate(true)
	encounter = encounter_data.duplicate(true)
	enemy = BattleActorState.from_enemy_data(enemy_data)

	_log("遭遇【%s】。" % enemy.display_name)
	if enemy.seal_layers.is_empty():
		_log("此敌人没有封缄层，执念归零即可结束。")
	else:
		_log("封缄层数：%d。" % enemy.seal_layers.size())
	_start_player_turn()


func use_skill(skill_id: String) -> bool:
	if phase != Phase.PLAYER_TURN:
		_log("现在不能下达指令。")
		_emit_changed()
		return false

	var cost := get_skill_cost(skill_id)
	if lamplight < cost:
		_log("灯火值不足，无法使用【%s】。" % get_skill_label(skill_id))
		_emit_changed()
		return false

	phase = Phase.RESOLVING_COMMAND
	lamplight -= cost
	_log("使用【%s】，消耗 %d 点灯火。" % [get_skill_label(skill_id), cost])

	match skill_id:
		"open_seal":
			_apply_open_seal()
		"archive_seal":
			_apply_archive_seal()
		"return_to_sender":
			_apply_return_to_sender()
		"send_letter":
			_apply_send_letter()
		"see_through":
			_apply_see_through()
		"lamplight":
			_apply_lamplight()
		_:
			_log("尚未实现指令：%s。" % skill_id)

	if _check_victory_after_skill(skill_id):
		_emit_changed()
		return true

	if _party_defeated():
		_finish_defeat("灯火熄灭，记忆断线。")
		_emit_changed()
		return true

	_resolve_enemy_turn()
	if phase == Phase.VICTORY or phase == Phase.DEFEAT:
		_emit_changed()
		return true

	_tick_round_statuses()
	_start_player_turn()
	return true


func get_skill_cost(skill_id: String) -> int:
	var data := _skill_data(skill_id)
	var cost := int(data.get("cost_lamplight", 0))
	if party_statuses.has("wet_words") and cost > 0 and skill_id != "send_letter":
		cost += 1
	return cost


func get_skill_label(skill_id: String) -> String:
	var data := _skill_data(skill_id)
	return str(data.get("display_name", FALLBACK_SKILL_LABELS.get(skill_id, skill_id)))


func snapshot() -> Dictionary:
	return {
		"phase_id": phase,
		"phase_key": PHASE_KEYS.get(phase, "unknown"),
		"phase_label": PHASE_LABELS.get(phase, "未知阶段"),
		"turn_number": turn_number,
		"lamplight": lamplight,
		"max_lamplight": max_lamplight,
		"rain_noise": rain_noise,
		"clarity": clarity,
		"acheng_will": acheng_will,
		"acheng_max_will": acheng_max_will,
		"qi_will": qi_will,
		"qi_max_will": qi_max_will,
		"party_statuses": _status_labels(party_statuses),
		"enemy_name": enemy.display_name if enemy != null else "",
		"enemy_obsession": enemy.obsession if enemy != null else 0,
		"enemy_max_obsession": enemy.max_obsession if enemy != null else 0,
		"enemy_statuses": _status_labels(enemy.statuses if enemy != null else {}),
		"seal_lines": _seal_lines(),
		"intent_text": _intent_text(),
		"commands": _command_snapshots(),
		"reward_flags": reward_flags.duplicate()
	}


func _start_player_turn() -> void:
	var first_turn := turn_number == 0
	turn_number += 1
	if not first_turn:
		lamplight = min(max_lamplight, lamplight + lamplight_recovery)
		_log("灯火回升 %d 点，当前 %d/%d。" % [lamplight_recovery, lamplight, max_lamplight])

	current_intent = _choose_next_intent()
	intent_visible = party_statuses.has("seen_through") and not _rain_blocks_intent()
	phase = Phase.PLAYER_TURN
	_log("第 %d 回合。" % turn_number)
	_emit_changed()


func _apply_open_seal() -> void:
	if enemy.all_seals_revealed():
		_log("所有封缄已经拆开。")
		enemy.damage_obsession(6)
		return

	var layer := enemy.current_seal_layer()
	var required_skill := str(layer.get("reveal_skill", "open_seal"))
	if required_skill != "" and required_skill != "open_seal":
		_log("这一层封缄需要先用【%s】处理。" % get_skill_label(required_skill))
		return

	var required_status := str(layer.get("requires_status", ""))
	if required_status != "" and not enemy.has_status(required_status):
		_log(str(layer.get("locked_hint", "封缄仍然紧闭，还没有露出可拆的缝。")))
		return

	_reveal_layer(layer)


func _apply_archive_seal() -> void:
	enemy.add_status("archived", 1)
	var damage := 10
	var weakness := str(enemy.metadata.get("weakness_after_reveal", ""))
	var last_layer := enemy.last_revealed_layer()
	if weakness == "archive_seal" or str(last_layer.get("weakness", "")) == "archive_seal":
		damage = 20
		_log("封存压住了刚暴露出的弱点。")
	enemy.damage_obsession(damage)
	_log("敌方执念下降 %d，下一次强力行动会被压制。" % damage)


func _apply_return_to_sender() -> void:
	var tags := _intent_tags(current_intent)
	var countered := tags.has("lie") or tags.has("counterable") or enemy.has_status("lie_shroud")
	if countered:
		enemy.remove_status("lie_shroud")
		party_statuses.erase("bound_by_lie")
		enemy.add_status("returned_intent", 1)
		enemy.add_status("seal_loosened", 3)
		enemy.damage_obsession(16)
		_log("退回命中：谎言被折返，封缄松动。")

		var layer := enemy.current_seal_layer()
		if str(layer.get("reveal_skill", "")) == "return_to_sender":
			_reveal_layer(layer)
	else:
		enemy.damage_obsession(4)
		_log("没有可退回的谎言，只削弱了少量执念。")


func _apply_send_letter() -> void:
	if party_statuses.has("bound_by_lie"):
		_log("阿澄被谎言缠住，暂时无法寄出。")
		return

	if not enemy.all_seals_revealed():
		var layer := enemy.current_seal_layer()
		if str(layer.get("reveal_skill", "")) == "send_letter":
			_reveal_layer(layer)
		else:
			_log("真相尚未拆明，寄出只会被雨声吞回。")
			return

	if enemy.has_status("lie_shroud"):
		_log("敌方仍有谎言护层，寄出被挡下。")
		return

	_log("信件找到了该去的方向。")


func _apply_see_through() -> void:
	party_statuses["seen_through"] = 2
	intent_visible = true
	if current_intent.is_empty():
		_log("雨里暂时没有新的敌意。")
	else:
		_log("照见敌方意图：【%s】%s" % [str(current_intent.get("display_name", "未知")), str(current_intent.get("intent_text", ""))])


func _apply_lamplight() -> void:
	var amount := 8
	if acheng_will <= qi_will:
		acheng_will = min(acheng_max_will, acheng_will + amount)
		_log("添灯照住阿澄，意志恢复 %d。" % amount)
	else:
		qi_will = min(qi_max_will, qi_will + amount)
		_log("添灯照住祈，意志恢复 %d。" % amount)
	party_statuses.erase("weak_lamplight")


func _resolve_enemy_turn() -> void:
	phase = Phase.ENEMY_TURN
	if enemy.has_status("returned_intent"):
		enemy.remove_status("returned_intent")
		_log("被退回的意图在雨中散开，敌方行动落空。")
		return

	var can_archive := bool(current_intent.get("can_archive", false)) or _intent_tags(current_intent).has("strong")
	if enemy.has_status("archived") and can_archive:
		enemy.remove_status("archived")
		_log("封存生效，【%s】被压下。" % str(current_intent.get("display_name", "敌方行动")))
		return

	var action_name := str(current_intent.get("display_name", "敌方行动"))
	_log("敌方行动：【%s】。" % action_name)

	var damage := int(current_intent.get("damage", 0))
	if damage > 0:
		_damage_party(damage, str(current_intent.get("target", "acheng")))

	var status_id := str(current_intent.get("status", ""))
	if status_id != "":
		party_statuses[status_id] = int(current_intent.get("status_turns", 2))
		_log("我方获得状态：%s。" % _status_label(status_id))

	var enemy_status_id := str(current_intent.get("enemy_status", ""))
	if enemy_status_id != "":
		enemy.add_status(enemy_status_id, int(current_intent.get("enemy_status_turns", 2)))
		_log("敌方获得状态：%s。" % _status_label(enemy_status_id))

	var rain_delta := int(current_intent.get("rain_noise", 0))
	if rain_delta != 0:
		rain_noise = max(0, rain_noise + rain_delta)
		var sign := "+" if rain_delta > 0 else ""
		_log("雨噪变化 %s%d，当前 %d。" % [sign, rain_delta, rain_noise])

	if _party_defeated():
		_finish_defeat("灯火熄灭，记忆断线。")


func _tick_round_statuses() -> void:
	for status_id in party_statuses.keys():
		var turns := int(party_statuses[status_id])
		if turns >= 999:
			continue
		turns -= 1
		if turns <= 0:
			party_statuses.erase(status_id)
		else:
			party_statuses[status_id] = turns

	if enemy != null:
		enemy.tick_statuses()

	if acheng_will <= 8 or qi_will <= 7:
		party_statuses["weak_lamplight"] = 999


func _check_victory_after_skill(skill_id: String) -> bool:
	var condition := str(enemy.metadata.get("victory_condition", "obsession_zero"))
	match condition:
		"all_seals_revealed":
			if enemy.all_seals_revealed():
				_finish_victory("封缄解除。")
				return true
		"use_send_letter_on_final_layer":
			if skill_id == "send_letter" and enemy.all_seals_revealed() and not party_statuses.has("bound_by_lie") and not enemy.has_status("lie_shroud"):
				_finish_victory("执念已寄出。")
				return true
		_:
			if enemy.obsession <= 0:
				_finish_victory("投递完成。")
				return true

	if condition != "use_send_letter_on_final_layer" and enemy.obsession <= 0:
		_finish_victory("投递完成。")
		return true
	return false


func _finish_victory(message: String) -> void:
	phase = Phase.VICTORY
	reward_flags = _collect_reward_flags()
	_log(message)
	if not reward_flags.is_empty():
		_log("奖励标记：%s。" % _join_values(reward_flags, ", "))


func _finish_defeat(message: String) -> void:
	phase = Phase.DEFEAT
	_log(message)


func _reveal_layer(layer: Dictionary) -> void:
	var revealed := enemy.reveal_current_layer()
	if revealed.is_empty():
		return
	var break_obsession := int(layer.get("break_obsession", 12))
	enemy.damage_obsession(break_obsession)
	var layer_name := str(layer.get("name", layer.get("id", "未命名封缄")))
	_log("拆出封缄：%s。" % layer_name)
	var text := str(layer.get("revealed_text", ""))
	if text != "":
		_log(text)
	_log("敌方执念下降 %d。" % break_obsession)

	var required_status := str(layer.get("requires_status", ""))
	if required_status != "":
		enemy.remove_status(required_status)


func _choose_next_intent() -> Dictionary:
	var pool: Array = []
	if enemy != null and not enemy.intent_cycle.is_empty():
		pool = enemy.intent_cycle
	elif enemy != null:
		for skill_id in enemy.skills:
			pool.append(_default_enemy_action(str(skill_id)))

	if pool.is_empty():
		pool.append(_default_enemy_action("basic_memory_scratch"))

	var raw = pool[intent_index % pool.size()]
	intent_index += 1
	return _normalize_enemy_action(raw)


func _normalize_enemy_action(raw) -> Dictionary:
	var action: Dictionary
	if typeof(raw) == TYPE_DICTIONARY:
		action = raw.duplicate(true)
	else:
		action = _default_enemy_action(str(raw))

	if not action.has("id"):
		action["id"] = "enemy_action"
	if not action.has("display_name"):
		action["display_name"] = str(action["id"])
	if not action.has("intent_text"):
		action["intent_text"] = "它的下一步仍藏在雨里。"
	if not action.has("tags"):
		action["tags"] = []
	return action


func _default_enemy_action(skill_id: String) -> Dictionary:
	match skill_id:
		"wet_paper_storm":
			return {
				"id": skill_id,
				"display_name": "湿信纷飞",
				"intent_text": "潮湿的信纸卷起雨声。",
				"damage": 5,
				"target": "party",
				"status": "wet_words",
				"status_turns": 2,
				"rain_noise": 1,
				"tags": ["attack", "wet"]
			}
		"false_reply":
			return {
				"id": skill_id,
				"display_name": "伪造来信",
				"intent_text": "一封不属于远方的回信正在成形。",
				"damage": 0,
				"status": "bound_by_lie",
				"status_turns": 2,
				"enemy_status": "lie_shroud",
				"enemy_status_turns": 2,
				"tags": ["lie", "counterable"]
			}
		"bridge_lamp_sways":
			return {
				"id": skill_id,
				"display_name": "桥灯摇晃",
				"intent_text": "桥灯忽明忽暗，雨声压近。",
				"damage": 3,
				"target": "qi",
				"rain_noise": 2,
				"tags": ["rain"]
			}
		"addressless_delivery":
			return {
				"id": skill_id,
				"display_name": "无址投递",
				"intent_text": "它把没有地址的信举到胸口。",
				"damage": 12,
				"target": "acheng",
				"can_archive": true,
				"tags": ["attack", "strong"]
			}
		"refuse_to_leave":
			return {
				"id": skill_id,
				"display_name": "不肯离开",
				"intent_text": "它把自己钉在黄昏里。",
				"damage": 0,
				"enemy_status": "lie_shroud",
				"enemy_status_turns": 2,
				"tags": ["protect", "lie"]
			}
		_:
			return {
				"id": skill_id,
				"display_name": "记忆刮痕",
				"intent_text": "旧记忆擦过信封边缘。",
				"damage": 4,
				"target": "acheng",
				"tags": ["attack"]
			}


func _damage_party(amount: int, target: String) -> void:
	match target:
		"party":
			var split := max(1, int(ceil(amount / 2.0)))
			acheng_will = max(0, acheng_will - split)
			qi_will = max(0, qi_will - split)
			_log("阿澄与祈各失去 %d 点意志。" % split)
		"qi":
			qi_will = max(0, qi_will - amount)
			_log("祈失去 %d 点意志。" % amount)
		_:
			acheng_will = max(0, acheng_will - amount)
			_log("阿澄失去 %d 点意志。" % amount)


func _party_defeated() -> bool:
	return acheng_will <= 0 or qi_will <= 0


func _rain_blocks_intent() -> bool:
	return rain_noise > clarity and not party_statuses.has("clear_mind")


func _intent_text() -> String:
	if current_intent.is_empty():
		return "无"
	if phase == Phase.VICTORY or phase == Phase.DEFEAT:
		return "战斗已结束"
	if intent_visible:
		return "%s：%s" % [str(current_intent.get("display_name", "未知")), str(current_intent.get("intent_text", ""))]
	if _rain_blocks_intent():
		return "雨噪太重，敌方意图被盖住"
	return "未照见"


func _seal_lines() -> Array:
	var lines: Array = []
	if enemy == null:
		return lines
	for index in range(enemy.seal_layers.size()):
		var layer = enemy.seal_layers[index]
		if typeof(layer) != TYPE_DICTIONARY:
			continue
		var prefix := "已拆" if index < enemy.revealed_layers else "未拆"
		var name := str(layer.get("name", layer.get("id", "封缄")))
		lines.append("%d. [%s] %s" % [index + 1, prefix, name])
	return lines


func _command_snapshots() -> Array:
	var rows: Array = []
	for skill_id in PLAYER_COMMANDS:
		var cost := get_skill_cost(skill_id)
		rows.append({
			"id": skill_id,
			"label": get_skill_label(skill_id),
			"cost": cost,
			"disabled": phase != Phase.PLAYER_TURN or lamplight < cost
		})
	return rows


func _skill_data(skill_id: String) -> Dictionary:
	var data = skills.get(skill_id, {})
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}


func _intent_tags(intent: Dictionary) -> Array:
	var tags = intent.get("tags", [])
	if typeof(tags) == TYPE_ARRAY:
		return tags
	return []


func _status_labels(statuses: Dictionary) -> Array:
	var labels: Array = []
	for status_id in statuses.keys():
		labels.append("%s(%d)" % [_status_label(str(status_id)), int(statuses[status_id])])
	return labels


func _status_label(status_id: String) -> String:
	return str(STATUS_LABELS.get(status_id, status_id))


func _collect_reward_flags() -> Array:
	var flags: Array = []
	var encounter_flags = encounter.get("reward_flags", [])
	if typeof(encounter_flags) == TYPE_ARRAY:
		flags.append_array(encounter_flags)

	var enemy_flags = enemy.metadata.get("reward_flags", [])
	if typeof(enemy_flags) == TYPE_ARRAY:
		for flag in enemy_flags:
			if not flags.has(flag):
				flags.append(flag)
	return flags


func _join_values(values: Array, separator: String) -> String:
	var text := ""
	for value in values:
		if text != "":
			text += separator
		text += str(value)
	return text


func _emit_changed() -> void:
	changed.emit(snapshot())


func _log(message: String) -> void:
	logged.emit(message)
