# 发行构建（M7.2 源码）

> 策略：里程碑才打包；M7.2 只更新源码/测试/文档，不生成 zip/SHA/Release。当前源码 0.7.2；最近试玩包仍是 M7/0.7.0。Godot 4.7 stable。

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

- `embed_pck=true`；`include_filter="*.json"`；`exclude_filter="build/*"`。
- 确认 `data/units.json`、`data/guilds.json`、`data/balance.json`、`data/counters.json`、`data/maps/*.json`、`data/campaign.json`、`data/levels/*.json` 进入包；不再包含 CSV。

## 打包

包内：`SimpleGame.exe`、`README.txt`、`PLAYTEST.md`、`RELEASE_NOTES.md`、`VERSION.txt`、截图（关卡选择/战斗/选中/协会/暂停/设置/存档/指南/缩放/编辑器）、`LICENSE-Godot.txt`。

里程碑打包时：整包解压到空目录做 headless/GUI/`--map-editor` 冒烟，记录文件大小与 SHA256；不把截图或测试脚本写进仓库 `build/` 以外。M7.2 本轮**不打包**。

## 验证

1. 解压到空目录运行；关卡选择出现，中文正常。
2. C1：Q/E 路线、Shift+右键集结点、槽位显示、下一波、悬赏、F2 步骤。
3. 拖框从道路外起框；滚轮缩放；小地图相机框同步；右键/Shift+右键。
4. 框选混合速度单位移动：队首/间距/等待/反向/跨路线汇合；到达成战线；远程支援受击前排。
5. 右键把交战单位拉走：移动优先途中攻击射程内目标，到达恢复；检查队列不卡、队首方向正确。
6. B 协会：功勋/晋级、下一级收益、需声望 gate、人情数值。
7. O 设置 / Space 暂停菜单设置：默认缩放、窗口缩放/全屏、站位顺序；暂停时仍暂停，Esc 先回暂停。
8. S 存档面板：手动备份、恢复、新存档；恢复/新档后设置仍保留。
9. 调试版 F3 或 `SimpleGame.exe --map-editor`：拖节点/连边/调宽 -> F8 校验 -> F5 保存 -> F9 重载；spawn id 不漂移。
10. 坏地图（缺基地/端点/出生口）validator 非 0；坏 JSON 有路径/类型错误。
11. 退出重进存档/设置仍在；无尽可进；`--headless --quit-after 180` 退出码 0；计算 SHA256。

## 发布

发布：itch.io 先行，Restricted 发 5-8 人；不提交 `build/`。发行版 F3 隐藏，地图编辑器通过 `--map-editor` 进入。
