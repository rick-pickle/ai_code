# 第二阶段交付说明

日期：2026-04-29

## 本阶段目标

把第一阶段的中文垂直切片设计推进成可继续开发的 Godot 4 工程骨架：包含地图视觉参考、玩家预制件、对话系统、战斗原型、地图内容数据和验证记录。

## 已交付内容

### Godot 工程

- `project.godot`：Godot 4 项目入口。
- `scenes/boot/Boot.tscn`：启动场景，加载数据后进入 GameRoot。
- `scenes/game_root/GameRoot.tscn`：当前根场景，加载旧邮局参考地图、阿澄玩家预制件和 DialogueLayer。
- `scenes/prefabs/Player.tscn`：阿澄玩家预制件，使用首批 sprite sheet，可用方向键移动。
- `scripts/autoload/data_registry.gd`：加载 letters、dialogues、enemies、skills、encounters、maps、npcs、interactables，并将 NPC 对话与调查文案扁平化为可直接调用的 dialogue。
- `scripts/autoload/game_state.gd`：全局 flag 与手册进度草案。

### 对话与交互

- `scripts/dialogue/dialogue_runtime.gd`：对话运行时，支持逐句、选项、speaker、portrait、`flag:` effects。
- `scenes/ui/DialogueLayer.tscn`：中文对话 UI 层。
- `scripts/prefabs/interactable.gd` 与 `scenes/prefabs/Interactable.tscn`：可复用交互点预制件。
- `docs/vertical_slice/dialogue_runtime.md`：对话运行时说明。

### 战斗原型

- `scenes/battle/BattleScene.tscn`：可单独运行的战斗原型场景。
- `scripts/battle/battle_state_machine.gd`：回合制战斗状态机。
- `scripts/battle/battle_scene.gd`：战斗 UI 与指令按钮逻辑。
- `scripts/battle/battle_actor_state.gd`：敌人/封缄状态数据。
- `data/enemies/enemy_wet_paper_echo.json`：教学战 1 敌人。
- `data/enemies/enemy_bridge_lamp_shadow.json`：教学战 2 敌人。
- `data/enemies/enemy_return_letter.json`：Boss 无址回信。
- `docs/vertical_slice/battle_runtime.md`：战斗原型说明。

### 地图与内容

- `data/maps/*.json`：旧邮局、雨灯街、面包店、旧石桥、记忆石桥、旧钟楼外围。
- `data/npcs/vertical_slice_npcs.json`：祈、温衡、林茉、梁叔等 NPC 的中文对话与条件。
- `data/interactables/vertical_slice_interactables.json`：调查点、互动点、剧情触发和战斗触发。
- `docs/vertical_slice/map_and_content.md`：地图与内容数据包说明。

### 视觉资产

- `assets/maps/rainlamp_street_reference.png`：雨灯街视觉参考。
- `assets/maps/post_office_reference.png`：旧邮局视觉参考。
- `assets/sprites/characters/acheng_walk_4x4/sheet-transparent.png`：阿澄行走透明 sheet。
- `assets/sprites/characters/qi_hover_1x4/sheet-transparent.png`：祈悬浮透明 sheet。
- `assets/sprites/enemies/return_letter_idle_3x3/sheet-transparent.png`：无址回信透明 sheet。
- `docs/vertical_slice/map_asset_qc.md` 与 `docs/vertical_slice/asset_qc.md`：视觉资产 QC。

## 当前可运行点

1. 用 Godot 4 打开 `D:\ai_code`。
2. 运行项目入口 `res://scenes/boot/Boot.tscn`。
3. 进入 `GameRoot` 后应看到旧邮局参考图和阿澄玩家预制件。
4. 使用方向键移动阿澄。
5. 单独运行 `res://scenes/battle/BattleScene.tscn` 可测试战斗原型。
6. 在 `BattleScene` Inspector 中将 `debug_encounter_id` 改为 `enc_tutorial_bridge_lamp` 或 `enc_boss_return_letter`，可分别测试第二教学战和 Boss。

## 已验证

- 所有 JSON 均可用 UTF-8 解析。
- TSCN 中 `res://` 资源路径均存在。
- GDScript 中静态 `res://` 引用路径均存在。
- 地图出口、目标 spawn、NPC、内嵌对话、互动点、遭遇敌人引用均通过校验。
- 三张 sprite 工程用透明 sheet 均为 RGBA 且带 alpha。
- 两张地图参考图存在且尺寸可读。

## 未验证

本机 PATH 中没有 `godot` / `godot4` / `godot-console` 可执行文件，因此尚未运行 Godot headless 导入检查，也未做真实编辑器运行验证。

## 重要注意

- 当前地图图片是视觉参考，不是最终可编辑 TileMap。
- 地图 JSON 中坐标是垂直切片布局草案，尚未与生成地图参考图逐像素对齐。
- 阿澄和无址回信 sprite 的视觉方向很好，但正式工程前建议再生成更大格内留白版本。
- 祈原始提示词要求 2x2，但生成结果实际是 1x4；工程使用已正确切分的 `qi_hover_1x4`。

## 推荐下一阶段

1. 在 Godot 编辑器中跑一次项目和 BattleScene，修掉真实导入/脚本问题。
2. 统一地图数据坐标与地图参考图尺寸，决定使用 baked raster、layered raster 还是 TileMap。
3. 将旧邮局的互动点按实际图像坐标摆进场景。
4. 生成阿澄正式留白版、林茉、温衡、梁叔与两个教学敌人 sprite。
5. 给 DialogueLayer 套旧邮册式 UI 皮肤和中文字体。

