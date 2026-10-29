# SimpleGame

横版双线推兵策略游戏原型。设计文档在 [Docs/README.md](Docs/README.md)。

## 当前状态

M2 经济与第 1 关：

- 2 条平行路，第 1 关基地血量 20
- 金币自动收入、人口上限、击杀奖励、出兵冷却
- 6 兵种全部可出战；软克制、被动、投射物
- 农场/兵营各 2 个固定槽位，可建造/升级
- 第 1 关 4 波固定波次，含精英与双线压力
- 可点击卡片出兵、切路、建造；键盘快捷操作
- 占位矩形渲染；画布 640x360，窗口 1280x720

> M2 为系统测试，第 1 关暂时解锁全部 6 兵种与两种建筑；GDD 的逐关解锁（第 1 关仅剑盾/弓手/农场）在 M4 接入。

## 运行

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --path .
```

## 操作

| 输入 | 行为 |
|---|---|
| 点击出兵卡 | 在当前路出兵 |
| `1-6` | 在当前路出兵（剑盾/长矛/弓/法/骑/投石） |
| `Alt + 1-6` | 在另一条路出兵 |
| `Q` / `E` 或点击 LANE 标签 | 切换当前路 |
| `B` 或点击 BUILD | 打开/关闭建筑面板 |
| 点击建筑行 | 建造/升级对应槽位 |
| `R` | 重开第 1 关 |
| `Space` | 暂停/继续 |
| `Esc` | 退出 |

## 测试

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_sim.gd
```

覆盖：出兵/推进、跨路不交战、伤害/被动/溅射、基地胜负、金币/人口/冷却、农场/兵营、击杀奖励、固定波次、第 1 关数据、HUD 点击映射、确定性。

自动试玩（检查第 1 关可通关）：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/autoplay.gd
```

可选截图（需要图形环境）：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --path . --script tests/capture.gd
```

输出 `build/m2_screenshot.png` 与 `build/m2_buildings.png`（已 gitignore）。

## 目录

```text
data/units.json            兵种数据
data/levels/level_01.json  第 1 关波次
sim/                       纯逻辑模拟层（无 Node 依赖）
view/                      表现层 + 战斗 HUD
scenes/battle.tscn         M2 战斗场景
tests/                     无头测试 / 自动试玩 / 截图
Docs/                      完整 GDD
```

## 下一步（M3）

跟随镜头与小地图、推进线/拖拽小队、第 2-3 关、首轮外部试玩。
