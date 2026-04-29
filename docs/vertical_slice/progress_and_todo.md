# 当前进度与待做清单

更新日期：2026-04-29

## 当前阶段

项目处于“垂直切片工程骨架完成，等待 Godot 编辑器真实运行验证”的阶段。

目标垂直切片仍是 35-45 分钟体验：序章 + 第一封信《桥边等信的人》。当前已经具备剧情、数据、视觉参考、sprite 标杆、对话系统、战斗原型和 Godot 4 最小工程入口。

## 已完成

### 设计与文档

- 已确定游戏语言为中文。
- 已确定完整游戏目标体量为 5-8 小时。
- 已确定垂直切片范围：序章 + 第一封信《桥边等信的人》。
- 已确定核心玩法：无随机遇敌、轻策略回合制、“拆封三层真相”。
- 已确定成长方式：邮差手册，不使用传统刷经验等级。
- 已确定 UI 方向：旧邮册、信封、邮戳、蜡封、雨灯。
- 已完成垂直切片总览、剧情台词包、战斗设计包、Godot 落地包、交付说明和 QC 文档。

### Godot 工程骨架

- 已创建 `project.godot`。
- 已创建启动场景 `scenes/boot/Boot.tscn`。
- 已创建根场景 `scenes/game_root/GameRoot.tscn`。
- 已接入 `GameState` 与 `DataRegistry` Autoload。
- 已创建阿澄玩家预制件 `scenes/prefabs/Player.tscn`，可用方向键移动。
- `GameRoot` 当前会加载旧邮局参考地图、阿澄玩家和对话层。

### 数据

- 已完成第一封信 JSON：`data/letters/letter_001_bridge_waiter.json`。
- 已完成核心技能 JSON：`data/skills/core_skills.json`。
- 已完成三场遭遇 JSON：`data/encounters/vertical_slice_encounters.json`。
- 已完成三个敌人 JSON：湿信纸残影、桥灯影、无址回信。
- 已完成六张地图内容 JSON：旧邮局、雨灯街、面包店、旧石桥、记忆石桥、旧钟楼外围。
- 已完成 NPC 内容包：祈、纸伞铺老板、数雨点的小孩、林茉、温衡、年轻温衡、梁叔。
- 已完成互动点内容包：调查物、剧情拾取、Boss 触发、结尾钩子。
- `DataRegistry` 已支持读取并扁平化 NPC 对话和调查文案。

### 对话与交互

- 已完成对话运行时 `scripts/dialogue/dialogue_runtime.gd`。
- 已完成中文对话 UI `scenes/ui/DialogueLayer.tscn`。
- 已完成可复用交互物 `scenes/prefabs/Interactable.tscn`。
- 对话支持逐句、speaker、portrait、choices、`flag:` effects。

### 战斗原型

- 已完成战斗场景 `scenes/battle/BattleScene.tscn`。
- 已完成战斗状态机 `scripts/battle/battle_state_machine.gd`。
- 已支持意志、灯火值、敌方执念、封缄层、拆封、封存、退回、寄出、照见、添灯。
- 已支持三场战斗原型：湿信纸残影、桥灯影、Boss 无址回信。

### 视觉资产

- 已生成雨灯街视觉参考图：`assets/maps/rainlamp_street_reference.png`。
- 已生成旧邮局视觉参考图：`assets/maps/post_office_reference.png`。
- 已生成并后处理阿澄 4x4 行走 sprite。
- 已生成并后处理祈 1x4 悬浮 sprite。
- 已生成并后处理无址回信 3x3 Boss 待机 sprite。

### 验证

- 23 个 JSON 全部通过 UTF-8 解析。
- TSCN 与 GDScript 中静态 `res://` 路径全部存在。
- 地图出口、目标 spawn、NPC、内嵌对话、互动点、遭遇敌人引用通过校验。
- 三张 sprite 工程用透明 sheet 均为 RGBA 且带 alpha。
- 当前机器没有 `godot/godot4/godot-console`，尚未做 Godot 编辑器或 headless 运行验证。

## 当前可运行目标

用 Godot 4 打开 `D:\ai_code`。

可测试：

- 运行 `res://scenes/boot/Boot.tscn`：进入旧邮局参考图，看到阿澄，可方向键移动。
- 运行 `res://scenes/battle/BattleScene.tscn`：测试战斗原型。
- 在 `BattleScene` Inspector 中切换 `debug_encounter_id`：
  - `enc_tutorial_wet_paper`
  - `enc_tutorial_bridge_lamp`
  - `enc_boss_return_letter`

## P0 待做：下一阶段必须完成

- 在 Godot 4 编辑器里真实打开项目，修复导入、脚本、场景运行问题。
- 给项目设置中文字体，避免中文在 Godot 中显示异常。
- 统一旧邮局参考图与 `data/maps/post_office.json` 的坐标体系。
- 在旧邮局场景里摆放真实交互点：邮差手册、第一封湿信、公告板、空信箱、旧制服、雨窗。
- 把 `Interactable` 与地图数据连接起来，允许玩家靠近后触发调查文案。
- 给 `GameRoot` 增加基础地图切换能力，从旧邮局进入雨灯街。
- 将对话系统接入第一封信主流程：手册、湿信、祈提示、出门软锁。
- 给战斗场景增加从地图触发的入口：调用 `start_encounter(encounter_id)`。
- 跑通最短闭环：旧邮局查看手册和第一封信 -> 出门到雨灯街 -> 触发一个对话或调查点。

## P1 待做：垂直切片体验完善

- 将雨灯街、面包店、旧石桥的交互点按视觉参考图实际坐标摆进场景。
- 做最小 NPC 预制件，支持 `npc_id`、条件对话、朝向和交互范围。
- 做地图出口预制件，支持 `required_flags` 和 `locked_text`。
- 给 DialogueLayer 做旧邮册式 UI 视觉皮肤。
- 给战斗 UI 做旧信纸/封缄视觉表现。
- 为阿澄生成正式留白版 sprite，避免当前部分帧格内余量偏紧。
- 生成温衡、林茉、梁叔的 NPC sprite 和头像占位。
- 生成两个教学敌人：湿信纸残影、桥灯影。
- 生成核心特效：拆封、封存、退回、寄出。
- 增加雨声 ambience、邮局室内环境音、桥边环境音。

## P2 待做：高质量 Demo 打磨

- 将地图视觉参考拆成可编辑 TileMap 或 layered raster。
- 做雨水、水洼反光、灯光闪烁 shader。
- 做邮差手册 UI：待投信件、镇民名簿、邮戳能力、封存档案。
- 做存档界面“留存此刻”。
- 做失败重试与战斗前恢复点。
- 做章节结尾演出：第一封信寄出、第十三封信露出“澄”字、梁叔现身。
- 做标题界面：开始投递、继续旅程、调整设置、离开雨灯镇。
- 做设置界面：音量、文字速度、全屏、键位提示。
- 做 35-45 分钟完整流程测试，记录卡点和节奏问题。

## 已知风险

- 当前地图图像是视觉参考，不是最终 TileMap；坐标需要重新对齐。
- 当前没有真实 Godot 运行验证，可能存在编辑器导入或 GDScript 版本细节问题。
- 当前阿澄和无址回信 sprite 适合作为视觉标杆，但正式版建议再生成更大边距版本。
- 祈的原始生成结果与提示词网格不一致，工程里使用的是已正确切分的 `qi_hover_1x4`。
- 对话和地图内容数据已经比较完整，但还未形成完整剧情流程状态机。

## 推荐下一步执行顺序

1. 用 Godot 4 打开项目，先修所有真实运行错误。
2. 接中文字体，确认对话框中文显示。
3. 摆旧邮局交互点，跑通旧邮局开场流程。
4. 接雨灯街地图切换，跑通“出门问路”。
5. 接一场教学战，从地图调查点进入 `BattleScene`。
6. 再开始补角色/NPC/敌人正式美术资产。

