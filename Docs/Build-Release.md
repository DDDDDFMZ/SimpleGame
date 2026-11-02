# 发行构建（M4）

> 目标：生成可分发的 Windows x86_64 试玩包。当前 M4 0.4.0。

## 前置

- Godot 4.7 stable
- `windows_release_x86_64.exe` 已放入 `%APPDATA%\Godot\export_templates\4.7.stable\`
- 预设：`export_presets.cfg` 的 `Windows Desktop`

## 导出

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --export-release "Windows Desktop" "build/SimpleGame.exe"
```

- `embed_pck=true` 单 exe；`include_filter="*.json"` 打包 units/guilds/levels。
- `exclude_filter="build/*"` 防止把发行物再打回 PCK。

## 打包

```bash
cd build
zip -j SimpleGame-M4-win64.zip SimpleGame.exe README.txt PLAYTEST.md RELEASE_NOTES.md VERSION.txt m4_level_select.png m4_battle.png m4_company.png LICENSE-Godot.txt
```

> 本机没有 `zip`，用 PowerShell：
> `Compress-Archive -Path ... -DestinationPath SimpleGame-M4-win64.zip -Force`

## 验证

1. 解压到空目录，运行 exe；关卡选择出现。
2. 契约 1 -> B 建交 Iron Oath -> 出兵 -> 压线 -> 通关。
3. 退出重进，星级/契约解锁/人情仍在。
4. 无尽可进入；结算最佳分。
5. `--headless --quit-after 120` 退出码 0。
6. 计算 SHA256，写入发布说明。

## 当前包内容

- `SimpleGame.exe`
- `README.txt`（M4 操作/已知限制）
- `PLAYTEST.md`（10 个反馈问题）
- `RELEASE_NOTES.md`
- `VERSION.txt`
- `m4_level_select.png` / `m4_battle.png` / `m4_company.png`
- `LICENSE-Godot.txt`

## 发布

- itch.io 先行，Restricted/Draft 发给 3-5 人；稳定后再开 Steam。
- 不上传 `build/` 到 Git（已 ignore）。
