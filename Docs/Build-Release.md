# 发行构建（M7）

> Windows x86_64 试玩包；当前 0.7.0。Godot 4.7 stable。

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

包内：`SimpleGame.exe`、`README.txt`、`PLAYTEST.md`、`RELEASE_NOTES.md`、`VERSION.txt`、M7 截图（关卡选择/战斗/选中/tooltip/协会/暂停/站位/存档/指南/缩放/编辑器）、`LICENSE-Godot.txt`。

当前 M7 包：`SimpleGame-M7-win64.zip`，约 37.7 MiB；SHA256 `8A6B5C6F0F6A88BD9508101BA58B71C8F39E84D475BB3149FF9AEC150E71802E`。已解压测试：headless、GUI、`--map-editor` 均退出码 0。

## 验证

1. 解压到空目录运行；关卡选择出现，中文正常。
2. C1：Q/E 路线、Shift+右键集结点、容量显示、下一波、悬赏、F2 步骤。
3. 拖框从道路外起框；滚轮缩放；小地图相机框同步；右键/Shift+右键。
4. B 协会：功勋/晋级、下一级收益、需声望 gate、人情数值。
5. Space 暂停菜单：继续/指南/备份进度/站位顺序/重开确认/返回确认；暂停时卡片/右键/相机不生效。
6. S 存档面板：手动备份、恢复、新存档；备份列表时间/星数；恢复/新档二次确认。
7. 站位顺序上/下调整后保存，重进仍保留。
8. 调试版 F3 或 `SimpleGame.exe --map-editor`：拖节点/连边/调宽 -> F8 校验 -> F5 保存 -> F9 重载。
9. 坏地图（缺基地/端点/出生口）validator 非 0。
10. 退出重进存档仍在；无尽可进；`--headless --quit-after 180` 退出码 0；计算 SHA256。

## 发布

发布：itch.io 先行，Restricted 发 5-8 人；不提交 `build/`。发行版 F3 隐藏，地图编辑器通过 `--map-editor` 进入。
