# 首批 Sprite 生成提示词

## 生成规则

- 用 `$generate2dsprite` 工作流生成。
- 原始生成图统一使用纯 `#FF00FF` 洋红背景。
- 后处理输出透明 PNG、逐帧 PNG 和 GIF。
- 文件名使用英文 ID，游戏内显示使用中文。
- 首批视觉标杆：阿澄、祈、无址回信。

## 阿澄 4x4 行走

```text
Asset type: player character, exact 4x4 top-down 3/4 pixel art walking sprite sheet for a refined 2D RPG.

Subject: A quiet young dead-letter post carrier named Acheng, wearing a deep teal short postal cloak, a clearly visible red scarf, an old brown leather mail satchel, wet dark boots, and carrying a small copper rain lantern. Androgynous youthful silhouette, calm and determined, not heroic armor, not modern clothes.

Sheet layout: exactly 16 equal cells in a 4x4 grid. Row 1 facing down, row 2 facing left, row 3 facing right, row 4 facing up. Column 1 neutral, column 2 left foot forward, column 3 neutral again, column 4 right foot forward.

Style: polished readable pixel art for a 3/4 top-down RPG, crisp dark outlines, elegant small details, rain-town mood, readable silhouette at small size.

Containment: the entire character must fit fully inside each cell, no scarf, lantern, bag, foot, or cloak edge may cross a cell edge, leave magenta margin on all four sides, use the same silhouette scale and bounding box in every frame.

Background: 100% solid flat #FF00FF magenta background, no gradients, no text, no labels, no UI, no cell borders.
```

## 祈 2x2 悬浮待机

```text
Asset type: companion spirit NPC, exact 2x2 pixel art hover idle animation sheet.

Subject: Qi, a tiny warm lantern spirit girl living inside a copper rain lantern. She has a small floating humanoid silhouette, amber-gold glow, translucent short mantle like a lamp flame, hair tips shaped like a candle wick, clever expressive eyes, gentle but slightly teasing personality. She should feel magical, warm, and protective, not fairy wings, not angel, not fire monster.

Motion: four-frame hover idle loop. Frame 1 neutral floating pose, frame 2 slight upward bob with soft lantern glow, frame 3 neutral pose with a tiny mantle sway, frame 4 slight downward bob returning to loop.

Style: polished readable pixel art for a refined 2D RPG, crisp silhouette, warm amber light accents, clean dark outline where needed, small but expressive.

Containment: the entire spirit and glow must fit fully inside each cell, detached glow must remain tightly grouped near the body, no glow, hair, mantle, or spark may cross a cell edge, leave magenta margin on all four sides, same scale and bounding box in every frame.

Background: 100% solid flat #FF00FF magenta background, no gradients, no text, no labels, no UI, no borders.
```

## 无址回信 3x3 Boss 待机

```text
Asset type: creature boss, exact 3x3 pixel art idle animation sheet in 3/4 battle view.

Subject: "Return Letter Without Address", a sorrowful memory-boss made from wet old letters, blank envelopes, torn postal seals, broken red postmarks, rainwater ink trails, and the reflected light of a stone bridge lantern. The creature should look like a folded mass of letters forming a hunched spectral body, with no normal human face, only an empty address window glowing faintly. Emotional tone: grief, waiting, denial, not evil.

Motion: nine-frame idle aura loop. The letter body slowly breathes and unfolds, wet paper edges tremble, broken postmarks pulse faintly, rain-ink drips inward, then the silhouette returns to its original shape. Keep it loopable and readable.

Style: polished readable pixel art boss sprite for a refined 2D RPG battle, strong silhouette, crisp edges, cold blue-gray wet paper with small red postmark accents and warm bridge-lamp highlights.

Containment: exactly 9 equal cells in a 3x3 grid, same boss identity in every cell, same bounding box and same pixel scale in every frame, subject fills about 60% of each cell, no paper strip, ink trail, glow, seal, or rain effect may cross a cell edge, leave magenta margin on all four sides.

Background: 100% solid flat #FF00FF magenta background, no gradients, no text, no labels, no UI, no borders.
```

## 核心特效

- 拆封：一道细金线划开信封，露出冷蓝色真相光。
- 封存：蜡封落下，红色邮戳压住敌人行动。
- 退回：信纸翻转成箭头，把敌方谎言弹回。
- 寄出：雨停一瞬，信件化成暖光飞向远处。

