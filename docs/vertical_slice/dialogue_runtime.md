# Dialogue Runtime

本框架提供中文 RPG 对话与交互的最小可用运行链路，文件名和类名保持英文，游戏内可见文案保持中文。

## 组成

`scripts/dialogue/dialogue_runtime.gd`

负责读取 `data/dialogues/*.json`、推进逐句文本、处理选择、写入 `flag:` effect。它会优先读取已加载的 `DataRegistry.dialogues`；如果当前场景没有 `DataRegistry`，会回退到 `res://data/dialogues` 目录查找 JSON 文件。

`scenes/ui/DialogueLayer.tscn` 与 `scripts/ui/dialogue_layer.gd`

负责显示说话人、头像、正文、选项和“继续”按钮。把该场景加入当前游戏场景后，可调用：

```gdscript
$DialogueLayer.start_dialogue("dlg_bridge_wenheng_01")
```

`scenes/prefabs/Interactable.tscn` 与 `scripts/prefabs/interactable.gd`

负责交互触发。实例上配置 `dialogue_id` 后，玩家进入范围并按 `ui_accept` 或 `interact` 会查找场景中的 `DialogueLayer` 并启动对应对话。也可以由玩家控制器直接调用：

```gdscript
interactable.interact()
```

## JSON 支持

当前支持的数据形状：

```json
{
  "id": "dlg_bridge_wenheng_01",
  "lines": [
    {
      "speaker": "acheng",
      "portrait": "acheng_calm",
      "text": "请问，您是温衡吗？"
    }
  ],
  "choices": [
    {
      "text": "继续询问",
      "next": 2,
      "effects": ["flag:asked_wenheng"]
    }
  ],
  "effects": ["flag:found_wenheng_bridge"]
}
```

逐句字段：

- `speaker`：说话人 ID。UI 内置了 `acheng`、`qi`、`wenheng`、`return_letter`、`system` 的中文显示名。
- `portrait`：头像 ID。UI 会尝试读取 `assets/portraits/{portrait}.png/webp/jpg/jpeg`，也可在 `DialogueLayer.portrait_paths` 中配置路径。
- `text`：正文，直接显示。
- `choices`：行内选项。显示该句后等待玩家选择。
- `effects`：进入该句时执行，目前支持 `flag:xxx`。

根级字段：

- `choices`：所有句子结束后显示的选项。
- `effects`：对话自然结束时执行，目前支持 `flag:xxx`。

选项字段：

- `text` 或 `label`：按钮文案。
- `next`：可以是 0 基 line index、line 的 `id`，或另一个 dialogue id。
- `next_line` / `line_index`：0 基 line index。
- `dialogue_id` / `next_dialogue`：跳转到另一个对话。
- `finish` / `end`：选择后结束当前对话。
- `effects`：选择时执行。

## 接入说明

不需要新增 Autoload。当前项目已有 `DataRegistry` 和 `GameState`，运行时会自动使用：

- `DataRegistry.dialogues`：读取已加载对话。
- `GameState.set_flag(flag_id, true)`：写入 `flag:` effect。

如果某个测试场景没有这些 Autoload，框架仍能直接读取 JSON；只是 `flag:` effect 会输出 warning，直到场景运行在完整项目环境中。

## 验证方法

1. 在任意测试场景实例化 `scenes/ui/DialogueLayer.tscn`。
2. 调用 `start_dialogue("dlg_bridge_wenheng_01")`，确认显示说话人、正文和继续按钮。
3. 连续按 `ui_accept`，确认逐句推进并在结束时关闭。
4. 结束后检查 `GameState.has_flag("found_wenheng_bridge")` 返回 `true`。
5. 实例化 `scenes/prefabs/Interactable.tscn`，配置 `dialogue_id = "dlg_bridge_wenheng_01"`，进入碰撞范围后按确认，确认可触发同一段对话。
