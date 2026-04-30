# Validation Trace - 2026-04-30

验证范围：Godot 4.2 像素 RPG 垂直切片 P0 smoke。

## 已执行

- 读取 `docs/vertical_slice/p0_refactor_progress_2026-04-30.md`，确认当前最新结论为二次验收候选，并复跑资源导入后的 Godot smoke。
- 执行 `python tools\validate_project.py`。
- 执行 `python -m py_compile tools\validate_project.py`。
- 执行 `& .\tools\run_godot_smoke.ps1`，该 runner 使用 `$env:TEMP\godot-4.2.2-codex\Godot_v4.2.2-stable_win64_console.exe`。

## 静态验证结果

- `python tools\validate_project.py` 通过。
- 摘要：JSON 26 个、`res://` 引用 69 个、地图 6 张、NPC id 7 个、合并 dialogue id 53 个、interactable id 33 个、enemy id 3 个、encounter 3 个、关键 PNG 16 个、关键 WAV 11 个。
- 结果：`Validation passed with 0 errors.`
- `python -m py_compile tools\validate_project.py` 通过，无输出。

## Godot Smoke 覆盖

新增 `tools/godot_smoke_test.gd`，用于：

- 加载 `res://scenes/game_root/GameRoot.tscn`。
- 依次切换 6 张地图：
  - `post_office`
  - `rainlamp_street`
  - `bakery`
  - `old_stone_bridge`
  - `memory_bridge`
  - `clocktower_exterior`
- 每张地图确认：
  - `current_map_id` 与目标地图一致。
  - 当前地图存在 `Background` 且有 texture。
  - 当前地图存在 `RuntimeBlockers` 且至少有 1 个子节点。
- 依次启动 3 个 encounter：
  - `enc_tutorial_wet_paper`
  - `enc_tutorial_bridge_lamp`
  - `enc_boss_return_letter`
- 每个 encounter 确认：
  - `GameRoot.active_battle` 已创建。
  - `BattleScene.active_encounter_id` 与目标 encounter 一致。
  - `BattleScene.active_enemy_id` 非空。
  - `BattleScene.machine` 已初始化。

新增 `tools/run_godot_smoke.ps1`，默认使用：

```powershell
$env:TEMP\godot-4.2.2-codex\Godot_v4.2.2-stable_win64_console.exe
```

运行：

```powershell
& .\tools\run_godot_smoke.ps1
```

期望输出：

```text
SMOKE_OK maps=6 blockers=6 encounters=3
```

## 当前剩余人工复测点

- 自动 smoke 已覆盖地图加载、RuntimeBlockers 和 3 场 encounter 初始化。
- 仍建议人工复测 blockers 体感、NPC 位置、interactable 范围、中文 UI、阿澄 4 向行走动画和音量平衡。

## Godot Smoke 实际结果

命令：

```powershell
& .\tools\run_godot_smoke.ps1
```

输出摘要：

```text
Godot Engine v4.2.2.stable.official.15073afe3 - https://godotengine.org
SMOKE_OK maps=6 blockers=6 encounters=3
```

结果：通过。

最终复跑时已无 Godot 退出期 `ObjectDB instances leaked at exit` warning。
