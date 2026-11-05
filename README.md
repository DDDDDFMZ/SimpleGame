# SimpleGame

俯视双线/多路自动推兵 + 冒险者公会经营原型。设计文档在 [Docs/README.md](Docs/README.md)。

## 当前状态

M7.2（源码 0.7.2）：索敌 120% 射程 + 受击者支援 + 队列/横向阵型 + 移动优先；不生成试玩包。

- 3 委托 + 无尽；关卡选择/星级/存档 v4
- 8 职业、3 协会；关内金币/声望/协会；局外委托/协会解锁/人情
- 俯视 2D 节点图：单玩家/单敌方基地，多出生路线与交汇；单位沿道路寻路并可反向
- 相机 2D 平移/缩放 0.5–1.5×；2D 小地图与相机框同步；框选锚点可在道路外
- 索敌：全兵种仅在自身射程 120% 内获取目标；不再无限同边追击，远程跨边只打射程内
- 道路碰撞槽位双方共享；满槽在节点排队；队列按编队/站位排序，队首在节点、队尾向后
- 单位默认道路中线；同纵向位置多单位并排时才横向展开，双方相遇各占半幅；部署/到达后成战线
- 小队编队：同路线最低速度、队首/队尾跟随、间距/等待/反向、跨路线分组、队长死亡提升
- 远程支援/近战反击：附近友军受击时共享攻击者，仅在自身射程内开火，不改变路线/不无限追击
- 移动优先：右键移动期间单位边移动边攻击射程内目标，不再被接敌打断；到达后恢复自动战斗
- 统一设置界面（关卡选择 `O` / 暂停菜单）：默认缩放、窗口缩放/全屏、站位顺序；独立 `user://settings.json`
- 数值唯一来源为 `data/*.json`，CSV 已移除；地图编辑器只追加缺失出生口，不重排已有 id
- 暂停菜单：继续/指南/备份进度/设置/重开确认/返回确认
- 存档：主档 + 轮换备份 + 恢复 + 新存档（新档前自动备份）；恢复/新档不改设置
- 全中文战斗 HUD、卡牌、tooltip、协会、结算、指南、关卡选择、地图编辑器
- 调试节点图编辑器：F3（调试版）或 `--map-editor`；节点/边/基地/宽度/校验/保存
- 自动试玩：C1 20/20、C2 6/20、C3 11/20、无尽 18 波（M7.2 索敌/阵型基线，真人待验证）
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
| 右键地面 | 移动选中单位（移动优先，途中可攻击射程内目标） |
| Shift+右键 | 设置当前路线集结点 |
| H / R | 驻守 / 返回集结点 |
| 滚轮 / - / = | 缩放镜头 |
| F / A-D-W-S / Home | 跟随/平移/回基地 |
| B / Space / Esc | 协会 / 暂停菜单 / 打开暂停菜单 |
| F1 / F2 | 战地指南（←/→ 翻页）/ 首局步骤 |
| O（关卡选择/暂停菜单） | 设置：默认缩放、窗口缩放/全屏、站位顺序 |
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
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_settings.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m7_squad.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m7_focus.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_flow.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/autoplay.gd
```

自动试玩：C1 20/20、C2 6/20、C3 11/20；无尽 18 波（第 18 波失守）。

数据校验：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tools/validate_data.gd
```

数值编辑见 [Docs/11-数值表与调参.md](Docs/11-数值表与调参.md)；地图格式/编辑器见 [Docs/12-地图格式与编辑器.md](Docs/12-地图格式与编辑器.md)。

## 目录

```text
autoload/              GameState + SaveService + SettingsService
data/units.json        职业数值/中文名/碰撞箱/站位顺序
data/guilds.json       协会定位/解锁/T0-T3
data/balance.json      经济/声望/容量/编队/支援全局数值
data/counters.json     攻型×甲型克制
data/maps/*.json       节点图地图（nodes/edges/spawns）
data/campaign.json     委托/协会解锁
data/levels/           3 委托 + 无尽
main/level_select.*    关卡选择/存档备份/设置入口
main/map_editor.*      调试节点图编辑器
sim/                   纯逻辑模拟层 + GameData/MapData/MapGraph
ui/settings_panel.*    共享设置模态
ui/ui_text.gd          攻/甲/职业/被动中文标签
view/                  HUD/2D 地图/相机/单位
scenes/battle.tscn     战斗场景
tests/                 数据/图/容量/编队/设置/存档/暂停/试玩/截图
Docs/                  完整 GDD
```

## 下一步（M8）

多基地、玩家地图编辑器/导入、2.5D 装饰高度、三协会费用差异化、晋升数值增益、契约规则与敌人专属单位。
