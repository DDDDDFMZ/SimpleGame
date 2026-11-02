# SimpleGame

横版双线自动推兵 + 冒险者公会经营原型。设计文档在 [Docs/README.md](Docs/README.md)。

## 当前状态

M4：冒险者公会重做 + M4 壳。

- 3 张契约 + 无尽；关卡选择/星级/存档
- 8 职业、3 协会（铁誓/绿荫/星环）
- 关内金币（津贴/波次/赏金）+ 声望（目标击杀+金币宣传）+ 协会合作（花金币解锁职业/上限）
- 局外契约/协会解锁 + 人情（使用次数/星级→小额永久 HP/伤害/价格）
- 2 路、1600 宽世界、跟随镜头、小地图拖选/右键移动/推进线
- 移动吸附/战斗优先/基地驻守修复
- 占位美术；中文关卡选择/契约简报；战斗 HUD 暂英文

## 运行

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --path .
```

## 操作

| 输入 | 行为 |
|---|---|
| 1-8 | 当前路招募职业（剑盾/长矛/骑士/弓手/盗贼/弩炮/法师/牧师） |
| Alt+1-8 | 另一路招募 |
| Q/E | 切换当前路 |
| 左键/拖框 | 选择单位；Shift 加选 |
| 右键地面 | 移动选中单位 |
| Shift+右键 | 设置当前路推进线 |
| H / R | 驻守 / 返回推进线 |
| Ctrl+R | 重开当前契约 |
| B | Company（声望 + 三协会） |
| F / A-D / Home | 跟随/平移/回基地 |
| Space / Esc | 暂停 / 返回契约列表 |

**先做**：按 `B` 打开 Company，花金币与协会建交（T0），否则职业卡锁定。然后 `Shift+右键` 把推进线压到前面。

## 测试

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m4_sim.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_sim.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_meta.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/autoplay.gd
```

自动试玩：3 契约 C1 20/20、C2 8/20、C3 1/20；无尽 12 波（脚本）。

可选截图：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --path . --script tests/capture.gd
```

输出 `build/m4_level_select.png`、`m4_battle.png`、`m4_company.png`。

## 目录

```text
autoload/              GameState + SaveService
data/units.json        8 职业
data/guilds.json       3 协会 T0-T3
data/levels/           3 契约
main/level_select.*    关卡选择主场景
sim/                   纯逻辑模拟层
view/                  HUD/地图/镜头/单位
scenes/battle.tscn     战斗场景
tests/                 单元/存档/试玩/截图
Docs/                  完整 GDD
```

## 下一步（M5）

真人试玩 3 契约+无尽；像素美术/音频；UI 中文化；道路宽度；英雄凯尔；第 4-5 契约。
