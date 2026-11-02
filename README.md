# SimpleGame

横版双线自动推兵 + 冒险者公会经营原型。设计文档在 [Docs/README.md](Docs/README.md)。

## 当前状态

M5：可理解性 + 战术清晰 + C3 重调 + CSV 数值工具。

- 3 契约 + 无尽；关卡选择/星级/存档
- 8 职业、3 协会；关内金币/声望/协会；局外契约/协会解锁/人情
- C1 首局 checklist；F1 Field Guide；F2 checklist 开关
- 卡牌攻/甲图标 + hover tooltip（HP/DPS/被动/克制/解锁）
- 下一波预览；TARGETS x/total；结算漏怪/花费/目标原因
- 数值唯一来源：`data/balance/*.csv`（Excel/LibreOffice 直接改）
- C3 已从 1/20 重调到自动 9/20；仍待真人试玩
- 占位矩形美术；战斗 HUD 英文，关卡选择/简报中文

## 运行

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --path .
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
| Ctrl+R | 重开当前契约 |
| B | Company（声望 + 三协会） |
| F1 | Field Guide（暂停） |
| F2 | 首局 checklist |
| F / A-D / Home | 跟随/平移/回基地 |
| Space / Esc | 暂停 / 契约列表 |

**先做**：B 打开 Company -> 花金币与 Iron Oath 建交 -> 1 招募 -> Shift+右键压线 -> 击杀金目标 -> PROMOTE。

## 测试

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_data.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_m4_sim.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_sim.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/test_meta.gd
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tests/autoplay.gd
```

自动试玩：C1 20/20、C2 8/20、C3 9/20；无尽 12 波。

数据校验：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tools/validate_data.gd
```

数值编辑见 [Docs/11-数值表与调参.md](Docs/11-数值表与调参.md)。

## 目录

```text
autoload/              GameState + SaveService
data/balance/*.csv     数值唯一来源
data/campaign.json     契约/协会解锁
data/levels/           3 契约 + 无尽
main/level_select.*    关卡选择主场景
sim/                   纯逻辑模拟层 + GameData
view/                  HUD/地图/镜头/单位
scenes/battle.tscn     战斗场景
tests/                 数据/单元/存档/试玩/截图
Docs/                  完整 GDD
```

## 下一步（M6）

两路地图数据化 + 调试地图编辑器 + 选中信息/分类；真图多基地/交汇/多向留 M7。
