# 首批 Sprite 资产 QC 记录

生成时间：2026-04-29

## 总结

首批视觉标杆已经生成并后处理。阿澄与无址回信的美术方向可作为项目标杆；祈的原始图生成成了 1x4 横排而非提示词要求的 2x2，因此已按 1x4 重新切分出正确工程版本。

## 阿澄 4x4 行走

路径：

- 原始图：`assets/sprites/raw/acheng_walk_4x4_raw.png`
- 透明 sheet：`assets/sprites/characters/acheng_walk_4x4/sheet-transparent.png`
- 动画预览：`assets/sprites/characters/acheng_walk_4x4/animation.gif`
- 元数据：`assets/sprites/characters/acheng_walk_4x4/pipeline-meta.json`

状态：概念标杆可用，正式工程前建议再生成一版更大格内留白。

QC：

- 视觉辨识度强：深青斗篷、红围巾、铜雨灯、旧邮包都清晰。
- 4 向行走结构完整。
- 源图部分帧触及格子上边缘，处理后透明 sheet 可预览，但正式动画建议再生成更严格留白版。

## 祈 1x4 悬浮待机

路径：

- 原始图：`assets/sprites/raw/qi_hover_2x2_raw.png`
- 正确切分：`assets/sprites/characters/qi_hover_1x4/sheet-transparent.png`
- 动画预览：`assets/sprites/characters/qi_hover_1x4/animation.gif`
- 元数据：`assets/sprites/characters/qi_hover_1x4/pipeline-meta.json`

状态：可进入工程作为第一版概念资产。

QC：

- 原始生成未遵循 2x2，实际是 1x4 横排。
- 已按 1x4 重新后处理，四帧无触边。
- 视觉效果偏“铜灯中的小灯灵”，符合祈的定位。
- 角色被画在灯内，若未来希望祈独立浮出铜雨灯，需要单独再生成“无灯笼版本”。

## 无址回信 3x3 Boss 待机

路径：

- 原始图：`assets/sprites/raw/return_letter_idle_3x3_raw.png`
- 透明 sheet：`assets/sprites/enemies/return_letter_idle_3x3/sheet-transparent.png`
- 动画预览：`assets/sprites/enemies/return_letter_idle_3x3/animation.gif`
- 元数据：`assets/sprites/enemies/return_letter_idle_3x3/pipeline-meta.json`

状态：概念标杆可用，正式工程前建议再生成一版更大边距。

QC：

- Boss 轮廓非常清楚，“湿信纸 + 空地址窗 + 红邮戳 + 桥灯暖光”成立。
- 3x3 结构完整，动画读感适合 Boss 待机。
- 源图少数帧触及格子边缘，处理后可预览；正式战斗版建议再生成更大留白，或由美术手动整理。

## 工程引用建议

当前可先在 Godot 原型中引用：

- `assets/sprites/characters/acheng_walk_4x4/sheet-transparent.png`
- `assets/sprites/characters/qi_hover_1x4/sheet-transparent.png`
- `assets/sprites/enemies/return_letter_idle_3x3/sheet-transparent.png`

暂不建议引用：

- `assets/sprites/characters/qi_hover_2x2/`，该目录来自错误网格切分，仅保留作处理记录。

