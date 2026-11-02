# 发行构建（M6）

> Windows x86_64 试玩包；当前 0.6.0。Godot 4.7 stable。

## 前置

- Godot 4.7 stable
- `windows_release_x86_64.exe` 在 `%APPDATA%\Godot\export_templates\4.7.stable\`
- 导出前跑数值/关卡/地图校验：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tools/validate_data.gd
```

应输出 `DATA VALID: units=8 guilds=3 maps=2 levels=3`。

## 导出

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --export-release "Windows Desktop" "build/SimpleGame.exe"
```

- `embed_pck=true`；`include_filter="*.json,*.csv"`；`exclude_filter="build/*"`。
- 确认 `data/balance/*.csv`、`data/maps/*.json`、`data/campaign.json`、`data/levels/*.json` 进入包。

## 打包

```bash
cd build
zip -j SimpleGame-M6-win64.zip SimpleGame.exe README.txt PLAYTEST.md RELEASE_NOTES.md VERSION.txt m6_level_select.png m6_battle.png m6_selection.png m6_tooltip.png m6_company.png m6_guide_1.png m6_guide_2.png m6_map_editor.png LICENSE-Godot.txt
```

本机无 zip，用 PowerShell `Compress-Archive`。

## 验证

1. 解压到空目录运行；关卡选择出现，中文正常。
2. C1：F2 首局步骤 / F1 两页指南 / 卡牌中文 tooltip / 下一波 / 悬赏。
3. B 建交 -> 招募 -> 压线 -> 目标 -> 晋升；Company 全中文。
4. 拖框选多兵：右侧选中面板显示数量/生命；切换协会/攻型/甲型/职业；点分组后右键移动、H 驻守、R 归线。
5. C1/C2/C3 地图宽段绘制正确；小地图/镜头不越界。
6. 调试版 F3 或 `SimpleGame.exe --map-editor`：改宽段 -> F8 校验 -> F5 保存 -> F9 重载仍生效。
7. 坏地图（宽度段缺口）validator 非 0；游戏不会以此导出。
8. 退出重进存档仍在；无尽可进。
9. `--headless --quit-after 120` 退出码 0；计算 SHA256。

## 当前包清单

`SimpleGame.exe`、`README.txt`、`PLAYTEST.md`、`RELEASE_NOTES.md`、`VERSION.txt`、`m6_level_select.png`、`m6_battle.png`、`m6_selection.png`、`m6_tooltip.png`、`m6_company.png`、`m6_guide_1.png`、`m6_guide_2.png`、`m6_map_editor.png`、`LICENSE-Godot.txt`。

当前 M6 包：`SimpleGame-M6-win64.zip`，约 37.3 MiB；SHA256 `06BCBB258747032DA56368BE754594C60C1575988A7A841A0A4D332591E7E96B`。已解压测试：headless、GUI、`--map-editor` 均退出码 0。

发布：itch.io 先行，Restricted 发 5-8 人；不提交 `build/`。发行版 F3 隐藏，地图编辑器通过 `--map-editor` 进入。
