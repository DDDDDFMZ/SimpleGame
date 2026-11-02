# SimpleGame

横版双线自动推兵 + 冒险者公会经营原型。设计文档在 [Docs/README.md](Docs/README.md)。

## 当前状态

M6：两路地图数据化 + 调试地图编辑器 + 选中信息/分类 + 全中文界面。

- 3 委托 + 无尽；关卡选择/星级/存档
- 8 职业、3 协会；关内金币/声望/协会；局外委托/协会解锁/人情
- 两路地图 JSON：基地/路线/宽度段/出生点；战斗仍是 lane+x
- 选中信息面板：数量/生命/位置/单兵详情；协会/攻型/甲型/职业分组；点分组后移动/驻守/归线
- 全中文战斗 HUD、卡牌、tooltip、协会、结算、F1 两页指南、关卡选择
- 调试地图编辑器：F3（调试版）或 `--map-editor`；改基地/路线/宽度段，F5 保存、F8 校验
- 数值唯一来源：`data/balance/*.csv`（Excel/LibreOffice 直接改）
- 自动试玩：C1 20/20、C2 8/20、C3 9/20；无尽 12 波
- 占位矩形美术；无音频；两条直线路；真图/多基地/交汇/多向留 M7

## 运行

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --path .
```

地图编辑器：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --path . --map-editor
```

## 操作

| 输入 | 行为 |
|---|---|
| 1-8 | 当前路招募职业 |
| Alt+1-8 | 另一路招募 |
| Q/E | 切换当前路 |
| 左键/拖框 | 选择单位；Shift 加选 |
| 右键地面 | 移动选中单位 |
| Shift+右键 | 设置推进线 |
| H / R | 驻守 / 返回推进线 |
| Ctrl+R | 重开当前委托 |
| B | 协会（声望 + 三协会） |
| F1 / F2 | 战地指南（←/→ 翻页）/ 首局步骤 |
| F3 | 地图编辑器（调试版） |
| F / A-D / Home | 跟随/平移/回基地 |
| Space / Esc | 暂停 / 委托列表 |

**先做**：B 打开协会 -> 花金币与铁誓会建交 -> 1 招募 -> Shift+右键压线 -> 击杀悬赏目标 -> 晋升。

## 测试

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_data.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m4_sim.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_sim.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_meta.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m6.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_flow.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/autoplay.gd
```

自动试玩：C1 20/20、C2 8/20、C3 9/20；无尽 12 波。

数据校验：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tools/validate_data.gd
```

数值编辑见 [Docs/11-数值表与调参.md](Docs/11-数值表与调参.md)；地图格式/编辑器见 [Docs/12-地图格式与编辑器.md](Docs/12-地图格式与编辑器.md)。

## 目录

```text
autoload/              GameState + SaveService
data/balance/*.csv     数值唯一来源
data/maps/*.json       两路地图（基地/路线/宽度段/出生点）
data/campaign.json     委托/协会解锁
data/levels/           3 委托 + 无尽
main/level_select.*    关卡选择主场景
main/map_editor.*      调试地图编辑器
sim/                   纯逻辑模拟层 + GameData/MapData
ui/ui_text.gd          攻/甲/职业/被动中文标签
view/                  HUD/地图/镜头/单位
scenes/battle.tscn     战斗场景
tests/                 数据/单元/存档/M6/试玩/截图
Docs/                  完整 GDD
```

## 下一步（M7）

俯视 2D 真图：多基地、多线路、交汇、多向移动、玩家地图编辑器；高度只做装饰。
