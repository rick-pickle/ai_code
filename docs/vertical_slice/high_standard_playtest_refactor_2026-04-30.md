# 高标准体验返工记录 2026-04-30

## 本轮目标

验收线程复查评分为 83/100，主要问题集中在真实玩家体验：战斗首屏看不到完整操作面板、对话框最大化被裁切、旧邮局第一目标不够明确、旧邮局局部遮挡/碰撞穿帮。本轮不新增剧情和系统，只修“看得见、点得到、读得清、知道去哪”。

## 修改摘要

- 重做 `BattleScene` 首屏布局：敌方视觉区扩展为战斗焦点，状态、封缄、日志、教学反馈和 6 个技能按钮在 960x540 与最大化截图中同时可见。
- 修复 `DialogueLayer` 底部安全布局：对话框锚到底部安全区域，默认窗口和最大化窗口均完整显示头像/占位、说话人、正文和继续按钮。
- 强化旧邮局开局引导：目标文案明确为“从门口向上走，到柜台正中查看邮差手册”，手册上方增加轻量 `v 手册` 标记。
- 降低空信箱抢首目标风险：`post_office_empty_mailbox` 需要 `postman_handbook_obtained` 后才生成。
- 优化旧邮局 blocker：左侧盆栽/柜体/伞架、柜台和低柜区域加了更明确的阻挡，减少角色身体压入大物件边缘。
- 新增窗口截图脚本和开局方向键 smoke，保留现有 headless smoke 与完整主线走查。

## 截图观察结论

截图输出目录：`docs/vertical_slice/screenshots/`

默认 960x540：

- `battle_wet_paper_960.png`：湿信纸残影、我方状态、敌方名称/执念、封缄信息、意图、日志、教学反馈、全部 6 个按钮均在首屏。
- `battle_bridge_lamp_960.png`：桥灯影独立敌图可见，2 层封缄完整，按钮区没有掉出窗口。
- `battle_boss_return_letter_960.png`：Boss 图像与 3 层封缄完整显示，日志和按钮区保留。
- `dialogue_handbook_960.png`、`dialogue_empty_mailbox_960.png`、`dialogue_first_letter_960.png`：对话框完整显示，未被窗口底部裁切。

最大化窗口，截图为 2560x1440：

- `battle_wet_paper_max.png`、`battle_bridge_lamp_max.png`、`battle_boss_return_letter_max.png`：战斗 UI 不再像只露出局部表单；敌方视觉、状态、封缄、日志、反馈和 6 个按钮全部可见。
- `dialogue_handbook_max.png`、`dialogue_empty_mailbox_max.png`、`dialogue_first_letter_max.png`：对话框完整停在底部安全区，正文和继续按钮可读可点。

## 开局方向键测试

命令：

```powershell
& "$env:TEMP\godot-4.2.2-codex\Godot_v4.2.2-stable_win64_console.exe" --path "D:\ai_code" --script "res://tools/godot_opening_keyboard_smoke.gd"
```

结果：

```text
OPENING_KEYBOARD_SMOKE_OK reached_prompt_seconds=2.25 start=(557.5,1168.3) end=(557.5,878.0)
```

结论：从旧邮局出生点出发，只按 `ui_up` 约 2.25 秒即可进入邮差手册提示区，之后互动成功并设置 `postman_handbook_obtained`。这满足“普通玩家 10-15 秒内找到第一目标”的要求。

## 完整主线窗口走查

命令：

```powershell
& "$env:TEMP\godot-4.2.2-codex\Godot_v4.2.2-stable_win64_console.exe" --path "D:\ai_code" --script "res://tools/godot_visual_playthrough.gd"
```

结果摘要：

```text
VISUAL_PLAYTHROUGH_OK steps=18
```

覆盖路径：

旧邮局手册/湿信 -> 湿信教程战 -> 雨灯街问路 -> 旧石桥温衡 -> 面包店真相 -> 桥灯教学战 -> 记忆桥调查 -> Boss -> 回现实 -> 旧钟楼第十三封信钩子。

关键 flag 均按预期推进：`postman_handbook_obtained`、`letter_001_received`、`tutorial_battle_01_cleared`、`found_wenheng_bridge`、`received_red_bean_bun`、`bakery_lie_discovered`、`tutorial_battle_02_cleared`、`bridge_memory_unlocked`、`memory_mailbox_seen`、`memory_unsent_letter_seen`、`memory_truth_line_seen`、`boss_return_letter_started`、`letter_001_sent`、`bridge_waiter_resolved`、`thirteenth_letter_seen`。

## 验证命令摘要

```powershell
python tools\validate_project.py
```

摘要：`Validation passed with 0 errors.` 6 张地图比例均为 `scale=1.000x1.000`，18 个关键 interactable 可达，3 场 encounter 奖励 flag 链路有效。

```powershell
python -m py_compile tools\validate_project.py
```

摘要：通过，无输出。

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_smoke.ps1 -TimeoutSeconds 60
```

摘要：

```text
VIEWPORT_SMOKE viewport=960x540 camera_zoom=1.00x1.00 visible_world=960x540
SMOKE_OK maps=6 blockers=6 encounters=3
SMOKE_WRAPPER exit_code=0
```

Boot headless：

```text
BOOT_SMOKE_OK loaded_game_root=true current_map=post_office frames=8
```

BattleScene headless：

```text
BATTLE_SCENE_SMOKE_OK encounter=enc_tutorial_wet_paper enemy=enemy_wet_paper_echo machine=true
```

截图脚本：

```text
EXPERIENCE_SCREENSHOT_OK dir=D:/ai_code/docs/vertical_slice/screenshots
```

## 已知剩余风险

- 对话层当前验证覆盖了三段短文本；后续如果加入长正文或多选项，需要给正文/选项区域补滚动或分页。
- 目标 marker 本轮只对旧邮局第一目标做了可视标记；后续可继续给第一封湿信、桥灯和记忆桥核心调查点加同等级轻量标记。
- 本轮以窗口截图、方向键 smoke、主线自动走查和 headless 验证为主，仍需验收线程进行真实手动复验。
