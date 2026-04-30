# P0/P1 返工进度记录

记录日期：2026-04-30  
项目：《雨灯镇：第十三封来信》2D 像素 RPG 垂直切片  
当前结论：P0/P1 关键返工已完成一轮，已进入二次验收候选状态。

## 1. 验收基线

上一轮验收结论为未通过，最终分数为 68/100。最终分项以验收方最后一次更正为准：

- 稳定性：12/15
- 好玩程度：17/25
- 画面像素风：13/20
- 剧情吸引力：18/20
- 交互手感：5/10
- 声音与演出：0/5
- 垂直切片完成度：3/5

本轮返工严格按验收方提出的 P0/P1/P2 执行。P0 必修项和 P1 关键补强已有可复跑验证。

## 2. 当前总状态

P0 的主要工程补齐已经完成一轮，包括地图视觉、中文字体、UI 主题、阿澄行走动画、NPC sprite、地图碰撞、主线 trace 校验。随后补了 P1 的声音、战斗反馈、出口/交互提示和主线 walkthrough。

当前状态：

- 可以提交二次验收候选。
- 静态验证、py_compile 和 Godot smoke 均已通过。
- 仍建议验收方做 480x270 实机复测、完整主线走查和音量/手感确认。
- 内部自评为 91/100，主要扣分来自程序生成音效仍偏占位、人工手感/视觉重叠仍需验收确认。

## 3. 已完成返工项

### P0-1：正式可视地图替换纯色占位

已新增 4 张 baked reference 地图图像，替换原先 `bakery`、`old_stone_bridge`、`memory_bridge`、`clocktower_exterior` 的运行时纯色占位问题：

- `assets/maps/bakery_reference.png`
- `assets/maps/old_stone_bridge_reference.png`
- `assets/maps/memory_bridge_reference.png`
- `assets/maps/clocktower_exterior_reference.png`

已新增对应 Godot 场景：

- `scenes/maps/Map_Bakery_Reference.tscn`
- `scenes/maps/Map_StoneBridge_Dusk_Reference.tscn`
- `scenes/maps/Map_MemoryBridge_Reference.tscn`
- `scenes/maps/Map_ClocktowerExterior_Reference.tscn`

已更新地图资产清单和提示词记录。

### P0-2：中文字体和旧邮册 UI 主题

已新增中文字体：

- `assets/fonts/SourceHanSansCN-Normal.ttf`

已新增 UI 主题脚本：

- `scripts/ui/rainlamp_theme.gd`

DialogueLayer 已改为旧邮册/信封纸色面板，BattleScene 已改为旧信纸/封缄风格，并接入敌方图像框、封缄区域、胜利/失败反馈。

### P0-3：阿澄新版行走 sprite 和动画驱动

已新增新版阿澄 4x4 行走资源：

- `assets/sprites/characters/acheng_walk_4x4_v2/sheet-transparent.png`
- `assets/sprites/characters/acheng_walk_4x4_v2/pipeline-meta.json`
- `assets/sprites/characters/acheng_walk_4x4_v2/animation.gif`
- `assets/sprites/characters/acheng_walk_4x4_v2/player_sheet-*.png`

已更新：

- `scenes/prefabs/Player.tscn`
- `scripts/player/player_controller.gd`

Player 已改用新版 sheet，并根据方向和移动状态驱动 4 向行走帧。

### P0-4：NPC sprite 和头像替代

已新增 NPC roster：

- `assets/sprites/characters/npc_roster/npc-1.png`：温衡
- `assets/sprites/characters/npc_roster/npc-2.png`：林茉
- `assets/sprites/characters/npc_roster/npc-3.png`：梁叔
- `assets/sprites/characters/npc_roster/npc-4.png`：纸伞铺老板
- `assets/sprites/characters/npc_roster/npc-5.png`：数雨点的小孩
- `assets/sprites/characters/npc_roster/npc-6.png`：祈

已新增头像替代资源：

- `assets/portraits/acheng.png`
- `assets/portraits/wenheng.png`
- `assets/portraits/young_wenheng.png`
- `assets/portraits/linmo.png`
- `assets/portraits/uncle_liang.png`
- `assets/portraits/umbrella_shop_owner.png`
- `assets/portraits/rain_counting_child.png`
- `assets/portraits/qi.png`
- `assets/portraits/return_letter.png`

NPC 不再依赖色块轮廓，`npc_interactable.gd` 根据 `npc_id` 映射对应 sprite。

### P0-5：地图碰撞和可走区域

已在 6 张地图 JSON 中新增 `blockers` 粗碰撞区域：

- `data/maps/post_office.json`
- `data/maps/rainlamp_street.json`
- `data/maps/bakery.json`
- `data/maps/old_stone_bridge.json`
- `data/maps/memory_bridge.json`
- `data/maps/clocktower_exterior.json`

`scripts/game_root/game_root.gd` 会运行时生成 `RuntimeBlockers` / `StaticBody2D`，玩家不再只受地图边界限制。

### P0-6：完整主线 trace 和关键数据

已更新：

- `data/interactables/vertical_slice_interactables.json`
- `data/dialogues/dlg_boss_return_letter_after.json`
- `tools/validate_project.py`

已接入：

- `post_office_first_letter` 触发 `enc_tutorial_wet_paper`。
- 桥灯条件触发第二场教学战。
- Boss 后对话增强。
- 验证脚本检查完整主线关键 flag trace。

主线关键 flag 已覆盖：

- `postman_handbook_obtained`
- `letter_001_received`
- `tutorial_battle_01_cleared`
- `found_wenheng_bridge`
- `bakery_lie_discovered`
- `tutorial_battle_02_cleared`
- `bridge_memory_unlocked`
- `memory_bridge_seen`
- `memory_mailbox_seen`
- `memory_unsent_letter_seen`
- `memory_truth_line_seen`
- `boss_return_letter_started`
- `letter_001_sent`
- `thirteenth_letter_seen`

### P1：声音、战斗反馈、交互提示

已新增雨声 ambience 和关键 SFX：

- `assets/audio/ambience/rain_loop.wav`
- `assets/audio/sfx/dialogue_advance.wav`
- `assets/audio/sfx/open_seal.wav`
- `assets/audio/sfx/archive_seal.wav`
- `assets/audio/sfx/return_to_sender.wav`
- `assets/audio/sfx/send_letter.wav`
- `assets/audio/sfx/see_through.wav`
- `assets/audio/sfx/lamplight.wav`
- `assets/audio/sfx/boss_appear.wav`
- `assets/audio/sfx/victory.wav`
- `assets/audio/sfx/defeat.wav`

已新增：

- `scripts/audio/audio_manager.gd`

并在 `project.godot` 中作为 Autoload 接入。DialogueLayer 已播放对话推进音，BattleScene 已播放技能、Boss 出现、胜利、失败音效。BattleScene 已新增反馈条。

出口和关键交互已增加“按确认/互动”提示，条件不足的出口显示“按确认查看”并保留 locked_text 反馈。

## 4. 已验证内容

已执行：

```powershell
python tools\validate_project.py
python -m py_compile tools\validate_project.py
powershell -ExecutionPolicy Bypass -File tools\run_godot_smoke.ps1
```

最新静态验证结果：

- JSON files parsed: 26
- `res://` references checked: 69
- maps indexed: 6
- NPC ids indexed: 7
- merged dialogue ids indexed: 53
- interactable ids indexed: 33
- enemy ids indexed: 3
- encounters checked: 3
- key PNG assets checked: 16
- key WAV assets checked: 11
- `Validation passed with 0 errors.`

Godot smoke 结果：

```text
SMOKE_OK maps=6 blockers=6 encounters=3
```

最终复跑已无资源 loader error，也无 Godot 退出期 `ObjectDB instances leaked at exit` warning。

## 5. 当前二次验收候选的剩余风险

1. 6 张地图的 blockers 已接入并通过 smoke，但仍需实机确认不会卡住、穿墙或遮挡关键交互。
2. 阿澄新版行走动画已接入，仍需验收方确认 4 向帧序和移动手感。
3. NPC sprite 已接入，仍需检查地图中尺寸、位置、遮挡和对话触发范围。
4. 完整主线已通过静态 trace，并有 walkthrough 记录；仍建议验收方实机走通一次。
5. 声音与演出已补最小可用闭环，但 WAV 为程序生成音色，正式质感和音量平衡仍可继续打磨。
6. 战斗视觉反馈已增强，仍需确认敌方像素图、封缄层、技能反馈、胜利/失败反馈在实机中足够清晰。

## 6. 当前工作树快照

截至最终集成复跑后，工作树快照如下：

- 暂存区：0 个 staged 文件。
- 已跟踪修改：`git status --short` 显示 24 个 modified 条目。
- 未跟踪路径：`git status --short` 显示 45 个 `??` 入口。
- 未跟踪文件展开数：`git ls-files --others --exclude-standard` 显示 77 个文件。
- 已跟踪 diff stat：24 files changed, 1195 insertions(+), 215 deletions(-)。
- 注意：上述 diff stat 不包含未跟踪 PNG、TTF、WAV、TSCN、GDScript、验证脚本和本文档本身。

`tools/__pycache__` 已清理，不应提交 Python 缓存文件。新增资源的 `.import` 文件已按 `.gitignore` 忽略。

## 7. 交接结论

当前返工已经从“工程骨架”推进到“二次验收候选”阶段。P0 必修项和 P1 关键补强已有自动化验证支撑。

从这里继续时，应交给验收方实机复测：跑启动入口、走完整主线、检查地图碰撞与提示、听雨声/SFX、确认 480x270 UI 和战斗反馈。若验收方给出低于 90 的具体返工项，再按优先级继续返修。
