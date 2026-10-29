# 发行构建（M3）

> 目标：生成可分发的 Windows x86_64 试玩包。当前是 M3 原型构建。

## 前置

- Godot 4.7 stable（编辑器）
- Godot 4.7 export templates 的 `windows_release_x86_64.exe`
  - 放置目录：`%APPDATA%\Godot\export_templates\4.7.stable\`
- 预设：项目根目录 `export_presets.cfg` 的 `Windows Desktop`

## 导出

```bash
"D:/Godot_v4.7/Godot_v4.7-stable_win64.exe" --headless --path . --export-release "Windows Desktop" "build/SimpleGame.exe"
```

预设开启 `embed_pck=true`，输出单 exe；JSON 通过 `include_filter="*.json"` 打进 PCK。

## 打包

```bash
cd build
zip -j SimpleGame-M3-win64.zip SimpleGame.exe README.txt PLAYTEST.md RELEASE_NOTES.md VERSION.txt m3_screenshot.png m3_buildings.png LICENSE-Godot.txt
```

> 如果 `zip` 不可用，用 PowerShell：`Compress-Archive -Path ... -DestinationPath ...`。

## 导出后检查

1. `SimpleGame.exe` 能启动，窗口/镜头/HUD 正常。
2. 能出兵、建造、压推进线、通关第 1 关。
3. 退出无报错；`%APPDATA%\Godot\app_userdata\SimpleGame\logs\` 无新的脚本错误。
4. 包内包含 README/PLAYTEST/VERSION/截图。
5. 计算 SHA256，写进发布说明。

## 当前包内容

- `SimpleGame.exe`
- `README.txt`（操作 + 已知限制）
- `PLAYTEST.md`（10 个反馈问题）
- `RELEASE_NOTES.md`（更新/已知限制）
- `VERSION.txt`（版本/日期/commit）
- `m3_screenshot.png` / `m3_buildings.png`
- `LICENSE-Godot.txt`（Godot 引擎 MIT 许可）

## 发布渠道

- 首选 itch.io（免费/隐藏项目均可），上传 zip，开启评论/反馈。
- 不开 Steam 页面，直到 M4 存档/关卡选择稳定。
- 不把 `build/` 提交进 Git（已在 `.gitignore`）。
