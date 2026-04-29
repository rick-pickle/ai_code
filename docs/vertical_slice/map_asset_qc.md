# 地图视觉资产 QC 记录

生成时间：2026-04-29

## 雨灯街视觉参考

路径：

- 图片：`assets/maps/rainlamp_street_reference.png`
- 提示词：`assets/prompts/rainlamp_street_map.txt`
- 清单：`assets/maps/map_asset_manifest.json`

规格：

- 尺寸：1024x1536
- 模式：RGB
- 类型：baked raster reference

QC：

- 冷雨与暖灯对比成立，石板路、水洼、桥、店铺、纸伞铺、面包店等元素清楚。
- 中央主路动线清晰，适合作为垂直切片外景布局标杆。
- 画面偏完整概念地图，不是可直接编辑 TileMap；正式工程建议拆成 TileMap 或 layered raster。
- 图中有类似招牌区域但无可读文字，符合“游戏内中文另走 UI/数据”的约定。

## 旧邮局视觉参考

路径：

- 图片：`assets/maps/post_office_reference.png`
- 提示词：`assets/prompts/post_office_map.txt`
- 清单：`assets/maps/map_asset_manifest.json`

规格：

- 尺寸：1122x1402
- 模式：RGB
- 类型：baked raster reference

QC：

- 旧邮局内部交互点明确：柜台、信格、邮差制服、红色信箱、桌上铜雨灯、窗外雨夜。
- 地面留有足够可走空间，适合后续按碰撞块重建。
- 画面氛围强，适合作为序章第一个室内场景标杆。
- 正式工程建议按 Godot 目标视口裁切或重绘为可编辑房间地图。

## 工程建议

短期原型：

- 可以将两张图作为静态背景放进 Godot 场景，配粗碰撞、多边形走区和交互点，快速验证剧情流程。

正式垂直切片：

- 雨灯街使用 layered raster 或 TileMap。
- 旧邮局可以优先用 baked raster + CollisionPolygon2D，因为它是单房间、交互点固定。
- 关键可交互物要拆为独立节点，便于发光、高亮、调查和 flag 控制。

