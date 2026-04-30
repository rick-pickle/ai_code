# 视野与 UI 占屏优化记录 - 2026-04-30

背景：玩家实机反馈“窗口里的画面太小，一个任务/对话/界面占了很多屏幕，地图只能看一点”。本轮目标是让默认窗口真正看到更多地图，而不是只拉大窗口像素。

## 关键改动

### 默认 viewport

已修改 `project.godot`：

- 旧值：`480x270`
- 新值：`960x540`
- `window/stretch/mode` 保持 `canvas_items`
- `window/stretch/aspect` 保持 `keep`
- `textures/canvas_textures/default_texture_filter=0` 保持 nearest，继续适配像素风

### 玩家相机

已修改 `scenes/prefabs/Player.tscn` 与 `scripts/player/player_controller.gd`：

- 旧相机：`Camera2D.zoom = Vector2(2, 2)`
- 新相机：`Camera2D.zoom = Vector2(1, 1)`
- 新增导出变量：`world_camera_zoom`，范围 `1.0 / 1.25 / 1.5`，默认 `1.0`

默认估算世界可见范围：

- 旧默认：`480x270 / zoom 2.0 = 240x135`
- 新默认：`960x540 / zoom 1.0 = 960x540`

也就是说，默认世界可视面积约为旧版的 16 倍。

### 对话 UI

已修改 `scenes/ui/DialogueLayer.tscn`：

- 对话框 `anchor_top` 从 `0.49` 调整为 `0.66`
- 对话框高度从约 `47%` 屏幕降到约 `30%`
- 头像框从 `50x50` 缩到 `40x40`
- margin/separation 已压缩
- 文本仍自动换行，但不会再默认占据接近半屏

### 战斗 UI

已修改 `scenes/battle/BattleScene.tscn`：

- 按 960x540 重新分配 margin 与 separation
- 敌方图像框从 `70x70` 调整到 `112x112`
- 封缄区与日志区获得更稳定高度
- 6 个技能按钮从横向一排改为 `GridContainer`，`3` 列布局，即视觉上为 `2x3`
- `LogLabel.fit_content=false`，避免日志按内容无限撑高

### 交互提示

已修改：

- `scenes/prefabs/Interactable.tscn`
- `scenes/prefabs/NPC.tscn`
- `scripts/prefabs/map_exit.gd`

普通交互、NPC、出口提示统一压缩为 12px 字号，并缩小提示框高度，减少多个提示同时出现时遮挡画面。

## Smoke 新增视野输出

`tools/godot_smoke_test.gd` 现在输出：

```text
VIEWPORT_SMOKE viewport=960x540 camera_zoom=1.00x1.00 visible_world=960x540
```

这条记录用于验收默认窗口尺寸、Camera2D zoom 和估算世界可视范围。

## 验收视野标准对应

- 旧邮局起点：默认可见范围已从 `240x135` 提升到 `960x540`，应能看到门口、柜台主体和多个交互区域。
- 雨灯街：默认可见范围覆盖大段街区，能建立方向感。
- 旧石桥：默认可同时看到桥灯、温衡附近空间和通行方向。

## 已验证命令

```powershell
python tools\validate_project.py
python -m py_compile tools\validate_project.py
powershell -ExecutionPolicy Bypass -File tools\run_godot_smoke.ps1 -TimeoutSeconds 60
```

Godot smoke 关键输出：

```text
VIEWPORT_SMOKE viewport=960x540 camera_zoom=1.00x1.00 visible_world=960x540
SMOKE_OK maps=6 blockers=6 encounters=3
SMOKE_WRAPPER exit_code=0
```

Boot/BattleScene headless 启动仍通过：

```text
BOOT_SMOKE_OK loaded_game_root=true current_map=post_office frames=8
BATTLE_SCENE_SMOKE_OK encounter=enc_tutorial_wet_paper enemy=enemy_wet_paper_echo machine=true
```

## 剩余风险

- 需要验收方实机确认 960x540 下中文字号是否舒适。
- 地图边缘暴露风险较低，因为地图参考图大于 viewport，且 Camera2D 仍有边界限制；但实际走到边缘时仍建议复测黑边/边界体感。
- `world_camera_zoom` 已可配置，但暂未做设置菜单，后续可接入 1.0 / 1.25 / 1.5 三档 UI。
