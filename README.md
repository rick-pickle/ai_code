# 雨灯镇：第十三封来信

中文像素 2D RPG 垂直切片工程草案。

当前目标是先完成 35-45 分钟的垂直切片：序章与第一封信《桥边等信的人》。项目设计方向、剧情包、战斗包、Godot 4 落地方案和首批 sprite 提示词已放在 `docs/vertical_slice/`。

## 当前内容

- `docs/vertical_slice/README.md`：垂直切片总览
- `docs/vertical_slice/narrative_and_dialogue.md`：中文剧情与台词包
- `docs/vertical_slice/combat_design.md`：玩法与战斗设计包
- `docs/vertical_slice/godot_implementation.md`：Godot 4 工程与资产落地包
- `docs/vertical_slice/stage2_deliverable.md`：第二阶段交付说明
- `docs/vertical_slice/progress_and_todo.md`：当前进度与待做清单
- `docs/vertical_slice/asset_prompts.md`：首批 sprite 生成提示词
- `data/`：可读 JSON 数据草案
- `scripts/`：Godot 4 Resource 与 Autoload 草案
- `assets/prompts/`：可直接用于生成 sprite 的提示词

## 运行方式

用 Godot 4 打开 `D:\ai_code`，运行 `res://scenes/boot/Boot.tscn`。当前入口会加载旧邮局参考地图、阿澄玩家预制件和对话层。战斗原型可单独运行 `res://scenes/battle/BattleScene.tscn`。

## 约定

- 文件名与数据 ID 使用英文或拼音，游戏内显示文本使用中文。
- 剧情、任务、敌人、技能数据优先放 JSON，避免硬编码中文文本。
- Godot Resource 负责运行时引用与类型约束。
- 首批美术标杆为阿澄、祈、无址回信。
