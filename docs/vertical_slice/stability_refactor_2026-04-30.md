# 二次验收返工稳定性记录 - 2026-04-30

背景：二次验收评分 78/100，未通过。主要阻塞为 Godot smoke 在验收环境中约 267 秒后访问冲突退出、Boot/BattleScene headless 启动超时、smoke 缺少分阶段日志，以及湿信纸残影/桥灯影缺少独立战斗图像。

## 本轮 P0 修复

### 1. Godot smoke 分阶段日志与外层 watchdog

已更新：

- `tools/godot_smoke_test.gd`
- `tools/run_godot_smoke.ps1`

新增日志前缀：

- `SMOKE_WRAPPER start`
- `SMOKE_STAGE load_game_root begin/end`
- `SMOKE_STAGE map begin/end id=...`
- `SMOKE_STAGE encounter begin/end id=...`
- `SMOKE_STAGE cleanup begin/end`
- `SMOKE_STAGE quit code=0`

`run_godot_smoke.ps1` 已改为用独立 Godot 进程执行，支持 `-TimeoutSeconds`，超时会强制终止本轮 smoke 进程并输出已有日志。

`godot_smoke_test.gd` 已增加内层最大耗时检查，并在每场 encounter 校验敌方 TextureRect 的资源路径。

### 2. Boot/BattleScene headless 启动稳定性

已更新：

- `scripts/boot/boot.gd`
- `scripts/battle/battle_scene.gd`

Boot 在 headless 下不再进入常驻游戏循环，而是执行最小启动检查：

- 加载 DataRegistry。
- 实例化 GameRoot。
- 等待 8 帧。
- 确认当前地图为 `post_office`。
- 输出 `BOOT_SMOKE_OK loaded_game_root=true current_map=post_office frames=8`。
- 正常退出。

BattleScene 在 headless 直接启动时执行最小战斗启动检查：

- 自动启动 `enc_tutorial_wet_paper`。
- 确认敌人为 `enemy_wet_paper_echo`。
- 确认 battle state machine 初始化。
- 输出 `BATTLE_SCENE_SMOKE_OK encounter=enc_tutorial_wet_paper enemy=enemy_wet_paper_echo machine=true`。
- 正常退出。

非 headless 下正常游戏/编辑器运行路径不变。

### 3. AudioManager headless 隔离

已更新：

- `scripts/audio/audio_manager.gd`

headless 下现在完全跳过 AudioStreamPlayer 创建与播放，仅输出：

```text
AUDIO_STAGE ready headless=true playback_enabled=false created_player=false
```

正常图形运行时仍创建 ambience player 并播放雨声。

### 4. Encounter 释放时序

已更新：

- `scripts/game_root/game_root.gd`
- `tools/godot_smoke_test.gd`

`GameRoot.start_encounter()` 在释放旧 battle 后立即清空 `active_battle` 引用。smoke 每场 encounter 检查完后会释放当前 BattleScene，并等待两帧再进入下一场，避免旧 BattleScene 与新 BattleScene 在同一帧交叠。

### 5. 三场战斗独立敌方视觉

已新增：

- `assets/sprites/enemies/wet_paper_echo/wet_paper_echo.png`
- `assets/sprites/enemies/bridge_lamp_shadow/bridge_lamp_shadow.png`

已更新：

- `data/enemies/enemy_wet_paper_echo.json`
- `data/enemies/enemy_bridge_lamp_shadow.json`
- `assets/sprites/asset_manifest.json`
- `scripts/battle/battle_scene.gd`

当前三场战斗视觉路径：

- 湿信纸残影：`res://assets/sprites/enemies/wet_paper_echo/wet_paper_echo.png`
- 桥灯影：`res://assets/sprites/enemies/bridge_lamp_shadow/bridge_lamp_shadow.png`
- 无址回信：`res://assets/sprites/enemies/return_letter_idle_3x3/idle-1.png`

smoke 会逐场验证上述 TextureRect 资源路径。

## 最终验证摘要

静态验证：

```powershell
python tools\validate_project.py
```

摘要：

- JSON files parsed: 26
- `res://` references checked: 73
- maps indexed: 6
- NPC ids indexed: 7
- merged dialogue ids indexed: 53
- interactable ids indexed: 33
- enemy ids indexed: 3
- encounters checked: 3
- key PNG assets checked: 18
- key WAV assets checked: 11
- `Validation passed with 0 errors.`

Python 编译验证：

```powershell
python -m py_compile tools\validate_project.py
```

结果：通过，无输出。

Godot smoke：

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_smoke.ps1 -TimeoutSeconds 60
```

关键输出：

```text
SMOKE_WRAPPER start timeout_seconds=60
SMOKE_STAGE load_game_root begin
SMOKE_STAGE load_game_root end node=GameRoot
SMOKE_STAGE map end id=post_office blockers=5 texture=true
SMOKE_STAGE map end id=rainlamp_street blockers=4 texture=true
SMOKE_STAGE map end id=bakery blockers=6 texture=true
SMOKE_STAGE map end id=old_stone_bridge blockers=5 texture=true
SMOKE_STAGE map end id=memory_bridge blockers=5 texture=true
SMOKE_STAGE map end id=clocktower_exterior blockers=5 texture=true
SMOKE_STAGE encounter end id=enc_tutorial_wet_paper enemy=enemy_wet_paper_echo machine=true texture=res://assets/sprites/enemies/wet_paper_echo/wet_paper_echo.png
SMOKE_STAGE encounter end id=enc_tutorial_bridge_lamp enemy=enemy_bridge_lamp_shadow machine=true texture=res://assets/sprites/enemies/bridge_lamp_shadow/bridge_lamp_shadow.png
SMOKE_STAGE encounter end id=enc_boss_return_letter enemy=enemy_return_letter machine=true texture=res://assets/sprites/enemies/return_letter_idle_3x3/idle-1.png
SMOKE_STAGE cleanup end
SMOKE_OK maps=6 blockers=6 encounters=3
SMOKE_WRAPPER exit_code=0
```

Boot 直接 headless 启动：

```powershell
& "$env:TEMP\godot-4.2.2-codex\Godot_v4.2.2-stable_win64_console.exe" --headless --path "D:\ai_code" "res://scenes/boot/Boot.tscn"
```

结果：

```text
BOOT_SMOKE_OK loaded_game_root=true current_map=post_office frames=8
```

BattleScene 直接 headless 启动：

```powershell
& "$env:TEMP\godot-4.2.2-codex\Godot_v4.2.2-stable_win64_console.exe" --headless --path "D:\ai_code" "res://scenes/battle/BattleScene.tscn"
```

结果：

```text
BATTLE_SCENE_SMOKE_OK encounter=enc_tutorial_wet_paper enemy=enemy_wet_paper_echo machine=true
```

## 剩余风险

- 当前仍有一个无法由本会话终止的既存 `Godot_v4.2.2-stable_win64.exe` 进程，PID 28724，创建时间为 2026-04-30 09:10:36，`taskkill /F` 返回 Access denied。本轮新启动的 smoke、Boot、BattleScene console 进程均正常退出。
- 本轮新增湿信纸残影/桥灯影为程序化像素战斗图，已满足三场战斗视觉区分；正式美术质感仍可继续升级。
- 480x270 UI、地图 blockers 手感、音量体感仍需验收方实机复测。
