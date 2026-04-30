# 声音与战斗反馈补强记录

记录日期：2026-04-30

## 范围

本轮只处理 P1 声音与战斗反馈补强，不修改地图、主线数据或战斗数值数据。

## 新增音频资源

- `assets/audio/ambience/rain_loop.wav`：旧邮局与雨灯镇底噪 ambience，运行时循环播放。
- `assets/audio/sfx/dialogue_advance.wav`：对话推进与选择确认。
- `assets/audio/sfx/open_seal.wav`：拆封。
- `assets/audio/sfx/archive_seal.wav`：封存。
- `assets/audio/sfx/return_to_sender.wav`：退回。
- `assets/audio/sfx/send_letter.wav`：寄出。
- `assets/audio/sfx/see_through.wav`：照见。
- `assets/audio/sfx/lamplight.wav`：添灯。
- `assets/audio/sfx/boss_appear.wav`：Boss 出现。
- `assets/audio/sfx/victory.wav`：胜利。
- `assets/audio/sfx/defeat.wav`：失败。

所有 WAV 均为程序生成的 22.05kHz、16-bit PCM 单声道短音效，目标是最小可用、可被 Godot 直接导入。

## 接入点

- `project.godot` 新增 `AudioManager` Autoload。
- `scripts/audio/audio_manager.gd` 负责缓存音频流、播放雨声 ambience、按 id 播放 SFX。
- `scripts/ui/dialogue_layer.gd` 在对话行切换与选项确认时播放 `dialogue_advance`。
- `scripts/battle/battle_scene.gd` 在战斗技能使用、Boss 出现、胜利、失败时播放对应 SFX。
- `scenes/battle/BattleScene.tscn` 新增旧信纸风格的 `FeedbackPanel`，用于显示技能结果与胜负反馈短句。
- `tools/validate_project.py` 增加关键 WAV 资源存在性与 RIFF/WAVE/PCM 头检查。

## 验证记录

- `python tools\validate_project.py`：通过，`Validation passed with 0 errors.`；关键 WAV 检查数为 11。
- `python -m py_compile tools\validate_project.py`：通过。
- `powershell -ExecutionPolicy Bypass -File tools\run_godot_smoke.ps1`：通过，输出 `SMOKE_OK maps=6 blockers=6 encounters=3`，退出码 0。
- 后续已让 `AudioManager` 在 headless smoke 下跳过实际音频播放，只保留资源/链路静态校验，避免 Godot 退出时出现非致命音频 playback leak warning。

## 剩余风险

- 程序生成音色可用但仍是占位级，后续可替换为正式 Foley/合成音色。
- 自动验证只能确认资源可读和场景可实例化，音量平衡、重复播放体感与 480x270 下的 UI 观感仍需要人工听测和实机看屏。
