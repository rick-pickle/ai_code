# 当前进度与待做清单

更新日期：2026-04-30  
权威返工记录：`docs/vertical_slice/p0_refactor_progress_2026-04-30.md`  
验证记录：`docs/vertical_slice/validation_trace_2026-04-30.md`、`docs/vertical_slice/mainline_walkthrough_2026-04-30.md`、`docs/vertical_slice/audio_feedback_trace_2026-04-30.md`

## 当前阶段

项目已经从上一轮 68/100 的“工程骨架”状态推进到二次验收候选状态。P0 必修项已经补齐一轮，P1 中声音、战斗反馈、出口/交互提示也已补上最小可用闭环。

当前仍建议由验收方实机复测 480x270 视觉、碰撞手感、提示遮挡、音量平衡和完整主线节奏，但自动化验证已经通过。

## 当前已完成重点

- 面包店、旧石桥、记忆桥、旧钟楼外围已补 baked reference 地图和 Godot 场景。
- 中文字体 `SourceHanSansCN-Normal.ttf` 已接入，DialogueLayer / BattleScene 已改成旧邮册、旧信纸风格。
- 阿澄新版 `acheng_walk_4x4_v2` 已接入，`player_controller.gd` 已驱动 4 向行走帧。
- 温衡、林茉、梁叔、纸伞铺老板、数雨点的小孩、祈已补 NPC sprite，并补主要头像替代资源。
- 6 张地图已新增 `blockers`，运行时生成 `RuntimeBlockers`。
- 关键交互与出口已增加“按确认/互动”提示；出口条件不足时会显示 locked_text。
- 湿信教程战、桥灯教学战、Boss 战已接入主线流程。
- Boss 后对话已增强，主线 walkthrough 已记录到第十三封信钩子。
- 已新增雨声 ambience 和 10 个关键 SFX，并接入 DialogueLayer / BattleScene。
- BattleScene 已加入敌方像素图、封缄区、技能反馈条、胜利/失败反馈。
- `tools/validate_project.py` 已扩展到检查主线关键 flag、关键 PNG 和关键 WAV。
- `tools/godot_smoke_test.gd` 与 `tools/run_godot_smoke.ps1` 已提供可复跑 Godot smoke。

## 已验证

最近一次静态验证：

```powershell
python tools\validate_project.py
python -m py_compile tools\validate_project.py
```

结果：

- JSON files parsed: 26
- `res://` references checked: 69
- maps indexed: 6
- merged dialogue ids indexed: 53
- interactable ids indexed: 33
- enemy ids indexed: 3
- encounters checked: 3
- key PNG assets checked: 16
- key WAV assets checked: 11
- `Validation passed with 0 errors.`

Godot smoke：

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_godot_smoke.ps1
```

结果：

```text
SMOKE_OK maps=6 blockers=6 encounters=3
```

本次最终复跑已无资源 loader error，也无 Godot 退出期 `ObjectDB instances leaked at exit` warning。

## 当前剩余复测点

- 480x270 下提示文字是否和 NPC 名牌、角色、战斗反馈条重叠。
- 6 张地图 blockers 的实际走位手感，尤其桥灯、记忆桥入口和关键交互点附近。
- 阿澄 4 向行走帧序与视觉留白是否达标。
- 程序生成音效的音量平衡、循环雨声体感和重复触发密度。
- 完整主线由验收方实机走一遍，确认节奏和情绪收束是否达到 90 分线。

## 交付判断

当前可以提交二次验收候选。自评不再是 68/100 的骨架状态；按当前自动验证和返工覆盖面，内部自评为 91/100。主要扣分来自程序生成音色仍偏占位、人工手感/视觉重叠还需要验收方实机确认。
