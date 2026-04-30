# 可玩性返工记录 - 2026-04-30

## 本轮目标

验收状态从 82/100 继续返工，重点关闭玩家实机反馈中的 P0/P1：

- Interactable 的 `required_flags` / `blocked_by_flags` gating 不再泄露剧情文本。
- 6 张 baked reference 地图的 JSON 坐标与 PNG 原始尺寸统一，运行时地图比例为 `1.000x1.000`。
- 关键交互区移到 blocker 前沿，避免靠大半径隔墙触发。
- Player 碰撞体改成脚底站位胶囊，降低视觉上插进柜台/墙体的概率。
- 增加轻量当前目标提示和三场战斗的教学提示。

## 已验证命令

### 静态验证

命令：

```powershell
python tools\validate_project.py
```

摘要：

- `Validation passed with 0 errors.`
- JSON：26。
- `res://` 引用：74。
- maps：6。
- encounters：3。
- key PNG：18。
- key WAV：11。
- 6 张地图比例 sanity 全部为 `scale=1.000x1.000`。
- 18 个关键 interactable 触发区均未完全落入 blocker。

### Python 编译

命令：

```powershell
python -m py_compile tools\validate_project.py
```

结果：通过。

### Godot smoke

命令：

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_smoke.ps1 -TimeoutSeconds 60
```

摘要：

- `VIEWPORT_SMOKE viewport=960x540 camera_zoom=1.00x1.00 visible_world=960x540`
- 6 张地图逐张输出 `scale=1.000x1.000`。
- 三场 encounter 均创建 battle state machine，并加载各自敌方贴图。
- `SMOKE_OK maps=6 blockers=6 encounters=3`
- `SMOKE_WRAPPER exit_code=0`

### 入口场景

Boot：

- 命令：Godot 4.2.2 headless 启动 `res://scenes/boot/Boot.tscn`。
- 结果：`BOOT_SMOKE_OK loaded_game_root=true current_map=post_office frames=8`。

BattleScene：

- 命令：Godot 4.2.2 headless 启动 `res://scenes/battle/BattleScene.tscn`。
- 结果：`BATTLE_SCENE_SMOKE_OK encounter=enc_tutorial_wet_paper enemy=enemy_wet_paper_echo machine=true`。

## 地图比例与关键交互可达性

本轮把地图 JSON `dimensions` 调整为实际 baked PNG 尺寸，并将 spawns、exits、blockers、NPC、interactables 按旧坐标比例换算到真实纹理坐标：

- `post_office`：`1122x1402`。
- `rainlamp_street`：`1024x1536`。
- `bakery`：`1024x1536`。
- `old_stone_bridge`：`1024x1536`。
- `memory_bridge`：`1024x1536`。
- `clocktower_exterior`：`1024x1536`。

已增加静态检查：

- 地图尺寸与参考 PNG 尺寸不一致，或 X/Y scale 差异超过阈值时失败。
- 关键 interactable 的 trigger rect 完全落在 blocker 内时失败。

重点修正的前沿交互区：

- `post_office_empty_mailbox` 移到 `mail_sorting_table` 下沿前方。
- `bakery_counter` 和 `bakery_red_bean_bun` 移到 `service_counter` 前沿。
- `old_bridge_lamp` 移到 `bridge_lamp_base` 下沿前方。

## 主线走查记录

本轮验证采用 headless 场景 smoke + 静态主线 flag trace，覆盖完整主线推进链。人工键鼠体感仍建议由验收方二次实测确认。

1. 旧邮局：`post_office_handbook` 设置 `postman_handbook_obtained`。
2. 旧邮局：`post_office_first_letter` 在手册 flag 后生成，设置 `letter_001_received`，启动 `enc_tutorial_wet_paper`。
3. 湿信教程战：胜利奖励 `tutorial_battle_01_cleared`。
4. 雨灯街：出口前往旧石桥依赖 `letter_001_received`。
5. 旧石桥：温衡对话 `dlg_bridge_wenheng_01` 设置 `found_wenheng_bridge`。
6. 面包店：`bakery_linmo_drawer` 在 `found_wenheng_bridge` 后可调查，设置 `linmo_drawer_discovered` 与 `bakery_lie_discovered`。
7. 旧石桥：`old_bridge_lamp` 条件分支启动 `enc_tutorial_bridge_lamp`。
8. 桥灯教学战：胜利奖励 `tutorial_battle_02_cleared`。
9. 旧石桥：再次调查桥灯设置 `bridge_memory_unlocked`。
10. 记忆桥：进图设置 `memory_bridge_seen`。
11. 记忆桥：调查 `memory_bridge_mailbox` 设置 `memory_mailbox_seen`。
12. 记忆桥：调查 `memory_bridge_unsent_letter` 设置 `memory_unsent_letter_seen`。
13. 记忆桥：`memory_bridge_truth_pool` 在前两项后生成，设置 `memory_truth_line_seen`。
14. 记忆桥：`memory_bridge_boss_trigger` 启动 `enc_boss_return_letter` 并设置 `boss_return_letter_started`。
15. Boss：胜利奖励 `letter_001_sent` 与 `bridge_waiter_resolved`，播放 Boss 后对话。
16. 回现实：`after_boss_to_old_stone_bridge` 可回到 `old_stone_bridge.after_boss`。
17. 雨灯街：`to_clocktower_exterior` 因 `letter_001_sent` 开放。
18. 旧钟楼外：`clocktower_thirteenth_letter` 设置 `thirteenth_letter_seen`。

## 剩余风险

- 本轮没有用可视窗口逐键人工走完全流程；已用 Godot headless smoke 和静态 flag trace 证明入口、地图、战斗、比例和主线数据链稳定。
- 地图参考图仍是 baked raster，不是最终 TileMap；坐标比例已稳定，但局部 blocker 手感仍建议由验收方实机走位确认。
- 当前机器仍能看到一个早先遗留的 Godot 进程 PID `28724`，本轮 smoke/Boot/BattleScene 新启动的进程均正常退出。
