# 主线可走性记录 - 2026-04-30

范围：地图出口提示、关键交互提示、6 张地图出口/交互/NPC/spawn/blockers 的 P0/P1 主线可走性。

## 完整主线路径

1. 旧邮局 `post_office`
   - 初始 spawn：`from_intro`，位置在门前通道内。
   - 交互 `post_office_handbook`，获得 `postman_handbook_obtained`。
   - 交互 `post_office_first_letter`，获得 `letter_001_received`，启动 `enc_tutorial_wet_paper`。
   - 战斗胜利后获得 `tutorial_battle_01_cleared`。
   - 出口 `to_rainlamp_street` 需要 `postman_handbook_obtained` + `letter_001_received`，通往 `rainlamp_street.from_post_office`。

2. 雨灯街 `rainlamp_street`
   - 进图获得 `entered_rainlamp_street`。
   - 可通过纸伞铺老板、数雨点的小孩和路牌获得问路/氛围信息。
   - 出口 `to_old_stone_bridge` 需要 `letter_001_received`，通往 `old_stone_bridge.from_rainlamp_street`。
   - 面包店出口 `to_bakery` 常开，用于后续调查。
   - 钟楼出口 `to_clocktower_exterior` 需要 `letter_001_sent`，Boss 后开放。

3. 旧石桥 `old_stone_bridge`
   - 进图获得 `entered_old_stone_bridge`。
   - 与温衡 NPC 对话 `wenheng_first_delivery`，获得 `found_wenheng_bridge`。
   - 桥灯 `old_bridge_lamp` 在 `found_wenheng_bridge` 后可触发 `enc_tutorial_bridge_lamp`。
   - 该战斗胜利后获得 `tutorial_battle_02_cleared`。
   - 需要回雨灯街，再进入面包店调查真相。

4. 面包店 `bakery`
   - 进图获得 `entered_bakery`。
   - `bakery_red_bean_bun` 可获得 `received_red_bean_bun`。
   - `bakery_linmo_drawer` 需要 `found_wenheng_bridge`，获得 `linmo_drawer_discovered` + `bakery_lie_discovered`。
   - 返回旧石桥。

5. 旧石桥二次调查
   - 在已拥有 `bakery_lie_discovered` + `tutorial_battle_02_cleared` 后，再调查 `old_bridge_lamp`。
   - 获得 `bridge_memory_unlocked`。
   - 出口 `to_memory_bridge` 需要 `bakery_lie_discovered` + `tutorial_battle_02_cleared`，且不能已有 `letter_001_sent`。

6. 记忆石桥 `memory_bridge`
   - 进图获得 `memory_bridge_seen` + `bridge_memory_unlocked`。
   - 交互 `memory_bridge_mailbox`，获得 `memory_mailbox_seen`。
   - 交互 `memory_bridge_unsent_letter`，获得 `memory_unsent_letter_seen`。
   - 交互 `memory_bridge_truth_pool`，需要 `memory_unsent_letter_seen` + `memory_mailbox_seen`，获得 `memory_truth_line_seen`。
   - 交互 `memory_bridge_boss_trigger`，需要 `memory_truth_line_seen`，获得 `boss_return_letter_started` 并启动 `enc_boss_return_letter`。
   - Boss 胜利后获得 `letter_001_sent` + `bridge_waiter_resolved`，播放 Boss 后对话。
   - Boss 后出口 `after_boss_to_old_stone_bridge` 通往 `old_stone_bridge.after_boss`。

7. Boss 后回收与结尾钩子
   - 旧石桥出现 Boss 后温衡/林茉对话。
   - 返回雨灯街，`to_clocktower_exterior` 已因 `letter_001_sent` 开放。
   - 钟楼外园 `clocktower_exterior` 进图获得 `entered_clocktower_exterior`。
   - 交互 `clocktower_thirteenth_letter`，获得 `thirteenth_letter_seen`。
   - 梁叔 NPC 对话可继续获得 `ending_hook_seen`。

## 本轮校准

- 出口进入范围时显示运行时提示：可通行显示“按确认/互动：出口名”，未满足条件显示“按确认查看：出口名”，按键后仍走原 `locked_text` 反馈。
- 普通交互/NPC 范围提示统一显示“按确认/互动：对象名”，避免玩家只看到名称但不知道按键。
- `post_office_handbook` 与 `post_office_first_letter` 增加柜台前沿矩形触发区，避免关键拾取点藏在柜台 blocker 后。
- `bakery_linmo_drawer` 增加柜台前沿矩形触发区，保证拿到 `found_wenheng_bridge` 后能调查抽屉。
- `clocktower_old_door` 增加建筑前沿矩形触发区，避免门点落入钟楼建筑 blocker 内。

## 剩余人工复测重点

- 480x270 下提示文字是否与角色/NPC 名牌重叠。
- 桥灯处战斗、记忆桥入口与桥灯 blocker 相邻，自动校验可过，但仍建议实机走位确认手感。
- 音频 trace 已通过静态/直接 smoke，但本轮未改音频；音量和循环体感仍需人工听测。
