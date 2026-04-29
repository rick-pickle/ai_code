# 地图与内容数据包：序章第一封信

本包补齐垂直切片中六个可走动/剧情地图的结构化内容：旧邮局、雨灯街、面包店、旧石桥、记忆石桥、旧钟楼外围。文件名与数据 ID 使用英文，游戏内显示文本使用中文。

## 数据范围

- `data/maps/*.json`：地图空间数据，包含场景 ID、尺寸、spawn 点、exits、NPC 实例、调查点引用和进入条件。
- `data/npcs/vertical_slice_npcs.json`：NPC 定义、条件对白、portrait ID、对白效果 flag。
- `data/interactables/vertical_slice_interactables.json`：各地图调查点与互动点，包含条件、重复文案、置 flag、遇敌触发。
- `assets/prompts/post_office_map.txt`：旧邮局地图图像生成提示词。
- `assets/prompts/rainlamp_street_map.txt`：雨灯街地图图像生成提示词。

## 地图流程

1. `post_office` 旧邮局：玩家从开场进入，调查邮差手册和第一封湿信，获得 `postman_handbook_obtained` 与 `letter_001_received` 后才能前往雨灯街。
2. `rainlamp_street` 雨灯街：问路枢纽。纸伞铺老板、小孩、梁叔提供温衡、倒影和旧钟楼线索；连接旧邮局、面包店、旧石桥，第一封信寄出后开放旧钟楼外围。
3. `bakery` 面包店：林茉给出红豆包和温衡线索。温衡拒绝拆信后，调查抽屉或触发林茉关键对白，获得 `bakery_lie_discovered`。
4. `old_stone_bridge` 旧石桥：温衡主场景。首次交信获得 `found_wenheng_bridge`；面包店真相与桥灯教学战后，桥灯开放记忆入口。
5. `memory_bridge` 记忆石桥：调查记忆信箱、未寄出的告别信、真话水洼后触发 `enc_boss_return_letter`。
6. `clocktower_exterior` 旧钟楼外围：第一封信寄出后的 Demo 钩子。第十三封信露出“澄”字，梁叔补上悬念台词。

## 关键 Flags

- `postman_handbook_obtained`：旧邮局手册已取得。
- `letter_001_received`：第一封信已确认。
- `asked_umbrella_owner_about_wenheng` / `asked_child_about_wenheng`：雨灯街问路信息。
- `found_wenheng_bridge`：桥边见到温衡并完成交信。
- `received_red_bean_bun`：林茉给出红豆包。
- `bakery_lie_discovered`：发现林茉多年代写来信。
- `tutorial_battle_02_cleared`：桥灯教学战完成，用于开放记忆入口。
- `bridge_memory_unlocked` / `memory_bridge_seen`：进入记忆回溯。
- `boss_return_letter_started`：Boss“无址回信”触发。
- `letter_001_sent` / `bridge_waiter_resolved`：第一封信完成。
- `thirteenth_letter_seen` / `ending_hook_seen`：旧钟楼结尾钩子完成。

## 运行时读取建议

地图加载时先读取目标 `data/maps/<map_id>.json`，使用 `default_spawn_id` 或转场传入的 `target_spawn_id` 放置玩家。NPC 和互动点通过 `npc_id`、`interactable_ids` 到内容包中解析。所有 `required_flags` 必须满足，任一 `blocked_by_flags` 命中则隐藏或锁定；互动成功后按 `effects` 中的 `flag:*`、`encounter:*`、`quest_step:*` 分派给对应系统。

JSON 中的坐标均为像素坐标草案，用于 Godot 4 原型摆位。地图美术替换后可以微调坐标，但不要改动 ID，以免剧情和存档引用失效。
