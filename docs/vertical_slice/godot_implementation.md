# Godot 4 工程与资产落地包

## 目录结构

建议文件名使用英文或拼音 ID，游戏内显示全部使用中文。

```text
res://
  project.godot
  scenes/
    boot/
    title/
    game_root/
    maps/
    battle/
    ui/
    prefabs/
  scripts/
    autoload/
    core/
    dialogue/
    quest/
    battle/
    ui/
    save/
  data/
    letters/
    dialogues/
    npcs/
    enemies/
    skills/
    encounters/
    items/
    maps/
    localization/
  resources/
    characters/
    enemies/
    skills/
    ui_themes/
  assets/
    sprites/
      characters/
      enemies/
      tilesets/
      ui/
      vfx/
    portraits/
    audio/
      bgm/
      ambience/
      sfx/
    fonts/
    shaders/
  docs/
    vertical_slice/
```

## 数据与资源分工

- `data/` 放 JSON，方便剧情、任务、数值快速迭代。
- `resources/` 放 Godot `.tres` / `.res`，用于运行时强类型引用。
- `assets/` 放导入资源，按角色、敌人、地图、UI、音频分层。
- 中文文本不硬编码进脚本，统一走剧情 JSON 或本地化 JSON。

## 场景清单

启动与根场景：

- Boot.tscn：加载配置、语言、存档。
- Title.tscn：标题界面，含“开始投递 / 继续旅程 / 调整设置”。
- GameRoot.tscn：常驻根节点，挂地图、UI、音频、转场。

地图场景：

- Map_PostOffice.tscn：旧邮局，主基地与教程起点。
- Map_RainlampStreet.tscn：雨灯街，NPC 与氛围展示。
- Map_Bakery.tscn：面包店，第一封信关键调查点。
- Map_StoneBridge_Dusk.tscn：黄昏石桥，温衡主场景。
- Map_MemoryBridge.tscn：记忆状态石桥，Boss 前置空间。
- Map_ClocktowerExterior.tscn：旧钟楼外围，Demo 结尾钩子。

系统场景：

- DialogueLayer.tscn：中文对话、头像、选项。
- PostmanHandbook.tscn：邮差手册。
- BattleScene.tscn：回合制战斗主场景。
- SealLayerPanel.tscn：Boss 三层封缄显示。
- SavePostcard.tscn：存档界面“留存此刻”。
- SceneTransition_Rain.tscn：雨幕转场。

可复用预制件：

- NPC.tscn
- Interactable.tscn
- InvestigationSpot.tscn
- MapExit.tscn
- RainController.tscn
- LanternLight.tscn
- QuestTrigger.tscn

## Godot Resource 草案

```gdscript
class_name CharacterDef
extends Resource

@export var id: String
@export var display_name: String
@export var role: String
@export var overworld_scene: PackedScene
@export var battle_scene: PackedScene
@export var portrait_set: Resource
@export var tags: Array[String]
```

```gdscript
class_name SkillDef
extends Resource

@export var id: String
@export var display_name: String
@export var description: String
@export var cost_lamplight: int
@export var target_type: String
@export var effect_type: String
@export var vfx_scene: PackedScene
```

```gdscript
class_name SealLayerDef
extends Resource

@export var id: String
@export var display_name: String
@export var reveal_text: String
@export var required_skill_id: String
@export var next_layer_id: String
```

```gdscript
class_name EncounterData
extends Resource

@export var id: String
@export var display_name: String
@export var trigger_type: String
@export var scene_id: String
@export var enemies: Array[Resource]
@export var required_flags: Array[String]
@export var reward_flags: Array[String]
@export var post_battle_dialogue_id: String
```

## 中文 UI 命名

主菜单：

- 开始投递
- 继续旅程
- 留存此刻
- 调整设置
- 离开雨灯镇

系统界面：

- 邮差手册
- 待投信件
- 未署名来信
- 镇民名簿
- 邮戳能力
- 邮包夹层
- 旧物记录

战斗界面：

- 意志：我方生命。
- 灯火值：技能资源。
- 执念：敌方核心状态。
- 封缄：Boss 真相层。
- 拆封、封存、退回、补写、寄出：核心指令。

## 首批像素资产

P0 必须完成：

- 阿澄 4 向行走、战斗 idle、拆封动作、受伤动作、6 个对话头像。
- 祈 hover idle、治疗/照明施法、6 个对话头像、小型 UI 提示头像。
- 温衡 NPC 站立或行走、3 个头像。
- 林茉 NPC、3 个头像。
- 梁叔结尾登场 sprite、2 个头像。
- Boss“无址回信” idle、攻击、崩解三套动画。
- 小怪“湿信纸残影”“桥灯影”。
- 技能特效：拆封、封存、退回、寄出。
- 地图 tileset：雨夜石板路、水洼反光、旧邮局内饰、面包店柜台、石桥、桥灯、河面雨纹。
- UI：邮差手册框体、信封按钮、邮戳图标、蜡封确认、明信片存档底图。

## 里程碑

- M0 工程骨架：Godot 4 项目结构、Autoload、场景切换、数据读取、中文字体导入。
- M1 可走动原型：阿澄可在邮局、雨灯街、石桥移动，支持交互点、NPC 对话、地图切换。
- M2 剧情闭环：完成第一封信从接取、调查、回溯、寄出的完整流程。
- M3 战斗闭环：完成 2 场教学战和 Boss“无址回信”。
- M4 美术替换：替换 P0 主角、NPC、Boss、地图、UI 资产。
- M5 音频与氛围：加入雨声分层、环境音、主旋律变奏、关键技能音效。
- M6 可测 Demo：35-45 分钟完整体验，支持存档、设置、失败重试、结尾钩子。

