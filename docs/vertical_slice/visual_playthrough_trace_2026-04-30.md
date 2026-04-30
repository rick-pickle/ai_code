# 可视窗口完整走查记录 - 2026-04-30

## 走查方式

本轮使用 Godot 4.2.2 正常窗口模式运行，不使用 headless：

```powershell
& "$env:TEMP\godot-4.2.2-codex\Godot_v4.2.2-stable_win64_console.exe" --path "D:\ai_code" --script "res://tools/godot_visual_playthrough.gd"
```

窗口走查脚本从 `res://scenes/boot/Boot.tscn` 起步，等待 Boot 切入 `GameRoot`，再按主线顺序把玩家移动到交互/出口触发区，触发对话、出口和战斗按钮。运行日志确认：

- `VISUAL_PLAYTHROUGH_STAGE begin display=Windows headless=false`
- `BOOT_STAGE change_scene begin target=res://scenes/game_root/GameRoot.tscn`
- `VISUAL_PLAYTHROUGH_STAGE boot_loaded current_map=post_office`
- 最终：`VISUAL_PLAYTHROUGH_OK steps=18`

## 逐步记录

1. 旧邮局 `post_office_handbook`：通过，获得 `postman_handbook_obtained`。
2. 旧邮局 `post_office_first_letter`：通过，获得 `letter_001_received`，启动湿信纸教程战。
3. 湿信纸教程战：`open_seal -> archive_seal -> archive_seal`，胜利，获得 `tutorial_battle_01_cleared`。
4. 旧邮局出口 `to_rainlamp_street`：通过，切到 `rainlamp_street`。
5. 雨灯街纸伞铺老板：通过，获得 `asked_umbrella_owner_about_wenheng`。
6. 雨灯街数雨点的小孩：通过，获得 `asked_child_about_wenheng`。
7. 雨灯街出口 `to_old_stone_bridge`：通过，切到 `old_stone_bridge`。
8. 旧石桥温衡 NPC：通过，获得 `found_wenheng_bridge`。
9. 旧石桥返回雨灯街：通过。
10. 雨灯街进入面包店：通过，切到 `bakery`。
11. 面包店 `bakery_red_bean_bun`：通过，获得 `received_red_bean_bun`。
12. 面包店 `bakery_linmo_drawer`：通过，获得 `bakery_lie_discovered`。
13. 面包店回雨灯街，再到旧石桥：通过。
14. 旧石桥 `old_bridge_lamp`：通过，启动桥灯影教程战。
15. 桥灯影教程战：`open_seal -> return_to_sender -> open_seal`，胜利，获得 `tutorial_battle_02_cleared`。
16. 旧石桥再次调查 `old_bridge_lamp`：通过，获得 `bridge_memory_unlocked`。
17. 旧石桥出口 `to_memory_bridge`：通过，切到 `memory_bridge`。
18. 记忆桥 `memory_bridge_mailbox`：通过，获得 `memory_mailbox_seen`。
19. 记忆桥 `memory_bridge_unsent_letter`：通过，获得 `memory_unsent_letter_seen`。
20. 记忆桥 `memory_bridge_truth_pool`：通过，获得 `memory_truth_line_seen`。
21. 记忆桥 `memory_bridge_boss_trigger`：通过，获得 `boss_return_letter_started`，启动 Boss。
22. Boss 战：`open_seal -> send_letter -> return_to_sender -> send_letter`，胜利，获得 `letter_001_sent` 与 `bridge_waiter_resolved`。
23. 记忆桥出口 `after_boss_to_old_stone_bridge`：通过，回到现实旧石桥。
24. 旧石桥回雨灯街：通过。
25. 雨灯街出口 `to_clocktower_exterior`：通过，切到 `clocktower_exterior`。
26. 旧钟楼外 `clocktower_thirteenth_letter`：通过，获得 `thirteenth_letter_seen`。

## 发现问题与修复

本轮可视窗口走查没有发现新的阻塞卡点：

- 未发现角色被 blocker 卡死。
- 未发现 interactable 提示出现但无法触发。
- 未发现关键交互区过小或完全落在 blocker 内。
- 未发现主线目标提示跳步；对话和战斗期间目标提示会隐藏。
- 未发现出口锁定提示阻断已满足条件的主线路径。

本轮已完成的相关修复文件：

- `tools/godot_visual_playthrough.gd`：新增窗口模式主线走查脚本。
- `scripts/battle/battle_scene.gd`：增强按钮、敌方受击、破封、胜负反馈。
- `scripts/battle/battle_state_machine.gd`：向 UI snapshot 暴露 `revealed_layers`。
- `scenes/battle/BattleScene.tscn`：扩大反馈条和结果提示的最小高度。

## 复测结果

窗口走查复跑结果：

- `display=Windows`
- `headless=false`
- 入口：`Boot.tscn`
- 完整主线：通过。
- 三场战斗：通过。
- 最终钩子：`thirteenth_letter_seen` 已设置。

已知问题：

- 本轮窗口走查由工具脚本逐节点驱动，能覆盖真实窗口、UI、对话、出口和战斗按钮路径；不是人工手按键盘逐步走位。仍建议验收线程用真实键鼠再做体感确认。
