# 战斗运行时原型

## 范围

本原型只负责垂直切片里的回合制战斗闭环，不改 Autoload、地图或对话系统。当前实现集中在：

- `res://scripts/battle/battle_actor_state.gd`
- `res://scripts/battle/battle_state_machine.gd`
- `res://scripts/battle/battle_scene.gd`
- `res://scenes/battle/BattleScene.tscn`

`BattleScene.tscn` 可以直接作为调试场景运行。默认读取遭遇 `enc_tutorial_wet_paper`，也可以在实例化后调用：

```gdscript
$BattleScene.start_encounter("enc_tutorial_bridge_lamp")
$BattleScene.start_encounter("enc_boss_return_letter")
```

如果未来要从地图或对话进入战斗，只需要在对应流程里加载 `BattleScene.tscn`，然后调用 `start_encounter(encounter_id)`。当前不需要新增 Autoload；若之后要跨场景保留战斗队列、失败重试点、战斗后回调，可以再整合一个 `BattleDirector` Autoload。

## 数据来源

运行时优先读取现有 `DataRegistry`：

- `DataRegistry.enemies`
- `DataRegistry.skills`
- `DataRegistry.encounters`

如果直接打开战斗场景且注册表尚未加载，`battle_scene.gd` 会调用 `DataRegistry.load_all()`。如果没有 Autoload，也会从 JSON 文件兜底读取。

敌人 JSON 支持这些战斗字段：

- `will`：敌方意志草案值，当前主要用于保留数值语义。
- `obsession`：敌方执念，教学战可用执念归零结算。
- `seal_layers`：封缄层数组。
- `intent_cycle`：敌方意图循环，按回合顺序使用。
- `victory_condition`：胜利条件。
- `weakness_after_reveal`：拆封后暴露的弱点。

封缄层支持：

- `reveal_skill`：拆出这一层需要的指令，例如 `open_seal`、`return_to_sender`、`send_letter`。
- `requires_status`：拆封前必须存在的敌方状态，例如桥灯影第二层需要 `seal_loosened`。
- `locked_hint`：条件不足时显示的提示。
- `break_obsession`：拆出后削减的执念。
- `weakness`：这一层暴露的弱点技能。

## 状态机

`BattleStateMachine` 的阶段：

- `SETUP`：载入敌人与技能数据。
- `PLAYER_TURN`：等待玩家选择指令。
- `RESOLVING_COMMAND`：处理拆封、封存、退回、寄出、照见、添灯。
- `ENEMY_TURN`：处理敌方意图。
- `VICTORY`：投递完成，返回奖励 flag。
- `DEFEAT`：灯火熄灭。

每次玩家指令后，若没有立即胜败，会进入敌方回合，然后刷新灯火并开始下一回合。

## 核心指令

拆封 `open_seal`：

- 检查当前封缄层的 `reveal_skill` 与 `requires_status`。
- 成功后显示真相文本并削减执念。

封存 `archive_seal`：

- 给敌方加 `archived`。
- 若下一次敌方意图带 `strong` 或 `can_archive`，该行动被压制。
- 若刚拆出的弱点是 `archive_seal`，会额外削减执念。

退回 `return_to_sender`：

- 如果敌方当前意图带 `lie` 或 `counterable`，会退回谎言。
- 移除我方 `bound_by_lie` 与敌方 `lie_shroud`。
- 给敌方加 `seal_loosened`，桥灯影第二层可在此后拆开。

寄出 `send_letter`：

- 若我方被 `bound_by_lie` 缠住，不能寄出。
- 若敌方还有 `lie_shroud`，寄出会被挡下。
- 对 `use_send_letter_on_final_layer` 胜利条件，必须最终封缄已揭示，并使用寄出结算。

照见 `see_through`：

- 给我方加 `seen_through`，显示当前敌方意图。
- 如果雨噪高于清明且没有清明状态，意图会被雨噪遮住。

添灯 `lamplight`：

- 恢复当前意志较低的一名角色。

## 垂直切片敌人

湿信纸残影 `enemy_wet_paper_echo`：

- 1 层封缄：表层情绪：慌乱。
- 教学目标：拆封后用封存压制强力行动。
- 胜利条件：执念归零。

桥灯影 `enemy_bridge_lamp_shadow`：

- 2 层封缄：等待、假回信。
- 教学目标：照见伪造来信，用退回令第二层封缄松动，再拆封。
- 胜利条件：全部封缄揭示。

无址回信 `enemy_return_letter`：

- 复用现有 JSON，不在本次改动中修改。
- 脚本会根据已有 `skills` 列表生成默认敌方行动。
- 现有第三层 `reveal_skill` 为 `send_letter`，因此原型里“寄出”可以拆出最终层并立即完成 `use_send_letter_on_final_layer` 结算。

## 验证建议

1. 在 Godot 4 中打开 `res://scenes/battle/BattleScene.tscn`。
2. 直接运行场景，默认进入湿信纸残影教学战。
3. 按 `拆封 -> 封存 -> 拆封/封存/添灯` 等指令，观察日志、执念、灯火值、封缄状态变化。
4. 在 Inspector 将 `debug_encounter_id` 改为 `enc_tutorial_bridge_lamp`，验证 `照见 -> 退回 -> 拆封` 流程。
5. 将 `debug_encounter_id` 改为 `enc_boss_return_letter`，验证三层封缄与寄出结算。

