# data/ 快速编辑指南

数值唯一来源是 JSON；不再读取 CSV。

## 数值

- `units.json`：对象 key = 单位 id。改 `cost/hp/damage/speed/range/attack_interval` 等；`display_name_cn` 是游戏内中文名；`body_width/body_height` 是碰撞箱/美术预留空间；`station_rank` 是默认站位顺序。
- `guilds.json`：对象 key = 协会 id；`tiers[]` 含 `cost/cap/rank_gate`。不要写 `tiers[].units`，职业层级由 `units.json` 的 `guild + relation_tier` 推导。
- `balance.json`：扁平键（`base_pop`、`promo_cost`、`road_slot_width`、`squad_spacing`、`target_range_mult`、`queue_timeout` 等）。数组写 `[1, 3, 5]`。
- `target_range_mult` 控制索敌窗口（射程×倍率）；`threat_memory` 控制受击支援记忆；`lateral_speed`/`queue_timeout` 控制横移与排队绕行。
- `counters.json`：攻型 → 轻/重甲倍率。
- JSON 不支持注释和尾逗号；小数用 `.`；UTF-8。

## 地图/关卡

- `maps/*.json`：`nodes` / `edges` / `spawns`；`width` 决定碰撞槽位，`entry` 是出生边。
- `levels/*.json`：`map` 引用地图；波次用 `route` 引用敌方出生口（如 `enemy_north`），不要再依赖 `lane` 索引。
- 图形编辑：调试版 F3，或 `SimpleGame.exe --map-editor`。拖动节点/道路、N 新增节点、C 连线、F8 校验、F5 保存、F9 重载。
- 改完重启游戏；运行：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tools/validate_data.gd
```

`DATA VALID: units=8 guilds=3 maps=2 levels=3` 才算通过。

## 设置

个性化设置不在 `data/`，而在 `user://settings.json`（Windows 通常位于 `%APPDATA%\Godot\app_userdata\SimpleGame\settings.json`）。游戏内关卡选择 `O` 或暂停菜单“设置”修改。
