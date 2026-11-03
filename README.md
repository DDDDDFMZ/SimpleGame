# SimpleGame

俯视双线/多路自动推兵 + 冒险者公会经营原型。设计文档在 [Docs/README.md](Docs/README.md)。

## 当前状态

M7：俯视节点图 + 多路线/交汇 + 摄像机缩放 + 道路容量/站位 + 存档备份 + 暂停菜单。

- 3 委托 + 无尽；关卡选择/星级/存档 v3
- 8 职业、3 协会；关内金币/声望/协会；局外委托/协会解锁/人情
- 俯视 2D 节点图：单玩家/单敌方基地，多出生路线与交汇；单位沿道路寻路并可反向
- 相机 2D 平移/缩放 0.5–1.5×；2D 小地图与相机框同步；框选锚点可在道路外
- 每条道路按宽度限制每方人数；满员在节点排队；兵种站位顺序默认来自 CSV，可在暂停菜单调整
- 暂停菜单：继续/指南/备份进度/站位顺序/重开确认/返回确认
- 存档：主档 + 轮换备份 + 恢复 + 新存档（新档前自动备份）
- 全中文战斗 HUD、卡牌、tooltip、协会、结算、指南、关卡选择、地图编辑器
- 调试节点图编辑器：F3（调试版）或 `--map-editor`；节点/边/基地/宽度/校验/保存
- 自动试玩：C1 20/20、C2 6/20、C3 7/20、无尽 15 波
- 占位矩形美术；无音频；玩家地图编辑器/多基地/2.5D 高度留后续

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
| 1-8 | 当前路线招募职业 |
| Alt+1-8 | 下一路线招募 |
| Q/E | 切换出生路线 |
| 左键/拖框 | 选择单位；Shift 加选 |
| 右键地面 | 移动选中单位 |
| Shift+右键 | 设置当前路线集结点 |
| H / R | 驻守 / 返回集结点 |
| 滚轮 / - / = | 缩放镜头 |
| F / A-D-W-S / Home | 跟随/平移/回基地 |
| B / Space / Esc | 协会 / 暂停菜单 / 打开暂停菜单 |
| F1 / F2 | 战地指南（←/→ 翻页）/ 首局步骤 |
| S（关卡选择） | 存档/备份/新存档 |
| F3（调试版） | 地图编辑器 |

**先做**：B 打开协会 -> 与铁誓会建交 -> 1 招募 -> Shift+右键设集结点 -> 击杀悬赏目标 -> 功勋达标后晋级声望。

## 测试

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_data.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m4_sim.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_sim.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_meta.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m6.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m7_capacity.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m7_camera.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m7_pause.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m7_save.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_flow.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/autoplay.gd
```

自动试玩：C1 20/20、C2 6/20、C3 7/20；无尽 15 波。

数据校验：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tools/validate_data.gd
```

数值编辑见 [Docs/11-数值表与调参.md](Docs/11-数值表与调参.md)；地图格式/编辑器见 [Docs/12-地图格式与编辑器.md](Docs/12-地图格式与编辑器.md)。

## 目录

```text
autoload/              GameState + SaveService
data/balance/*.csv     数值唯一来源（含 station_rank）
data/maps/*.json       节点图地图（nodes/edges/spawns）
data/campaign.json     委托/协会解锁
data/levels/           3 委托 + 无尽
main/level_select.*    关卡选择/存档备份面板
main/map_editor.*      调试节点图编辑器
sim/                   纯逻辑模拟层 + GameData/MapData/MapGraph
ui/ui_text.gd          攻/甲/职业/被动中文标签
view/                  HUD/2D 地图/相机/单位
scenes/battle.tscn     战斗场景
tests/                 数据/图/容量/相机/存档/暂停/试玩/截图
Docs/                  完整 GDD
```

## 下一步（M8）

多基地、玩家地图编辑器/导入、2.5D 装饰高度、三协会费用差异化、晋升数值增益、契约规则与敌人专属单位。
