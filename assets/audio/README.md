# 音频放这里

把音频文件丢进这个目录，用**固定的文件名**，游戏里就会自动生效（不用改代码）。

| 文件名 | 触发时机 |
|---|---|
| `jump.ogg` | 起跳 |
| `land.ogg` | 落地 |
| `vanish.ogg` | 方块消失 |
| `stomp.ogg` | 踩死怪 |
| `shatter.ogg` | 字块碎裂 |
| `transform.ogg` | 变成新字 |
| `coin.ogg` | 吃金币 |
| `hit.ogg` | 主角受击 |

- 后缀 `.ogg` / `.wav` / `.mp3` 都可以，只要**文件名主干**对得上。
- 缺文件不会报错，游戏启动时会在控制台列一份"还缺哪些"。
- 想加新音效：在 `scripts/systems/sfx.gd` 的 `NAMES` 数组里加一个名字，然后放同名文件。

代码用法：`Sfx.play("jump")`
