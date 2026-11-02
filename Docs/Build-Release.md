# 发行构建（M5）

> Windows x86_64 试玩包；当前 0.5.0。Godot 4.7 stable。

## 前置

- Godot 4.7 stable
- `windows_release_x86_64.exe` 在 `%APPDATA%\Godot\export_templates\4.7.stable\`
- 导出前跑数据校验：

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --script tools/validate_data.gd
```

## 导出

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --export-release "Windows Desktop" "build/SimpleGame.exe"
```

- `embed_pck=true`；`include_filter="*.json,*.csv"`；`exclude_filter="build/*"`。
- 确认 `data/balance/*.csv`、`data/campaign.json`、`data/levels/*.json` 进入包。

## 打包

```bash
cd build
zip -j SimpleGame-M5-win64.zip SimpleGame.exe README.txt PLAYTEST.md RELEASE_NOTES.md VERSION.txt m5_level_select.png m5_battle.png m5_tooltip.png m5_company.png m5_guide.png LICENSE-Godot.txt
```

本机无 zip，用 PowerShell `Compress-Archive`。

## 验证

1. 解压到空目录运行；关卡选择出现。
2. C1：F2 checklist / F1 guide / 卡牌 tooltip / NEXT WAVE / TARGETS。
3. B 建交 -> 招募 -> 压线 -> 目标 -> PROMOTE。
4. 改 `data/balance/units.csv` 某成本 -> 重开 -> 生效；坏数据 validator 失败。
5. 退出重进存档仍在；无尽可进。
6. `--headless --quit-after 120` 退出码 0；计算 SHA256。

## 当前包清单

`SimpleGame.exe`、`README.txt`、`PLAYTEST.md`、`RELEASE_NOTES.md`、`VERSION.txt`、`m5_level_select.png`、`m5_battle.png`、`m5_tooltip.png`、`m5_company.png`、`m5_guide.png`、`LICENSE-Godot.txt`。

发布：itch.io 先行，Restricted 发 5-8 人；不提交 `build/`。
