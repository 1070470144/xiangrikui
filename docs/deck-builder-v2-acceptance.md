# 卡组界面优化 · 2026-09-30

已接入 sprite-gen 生成的新温室背景，使用用户指定的 HTTPS 网关和 `gpt-image-2`。请求使用环境变量认证，项目文件不保存密钥。生成报告保存在 `art_source/generated/mm_tools/deck_builder/deck_background_v2.report.json`，源 PNG 实测为 1672×941，运行时按比例覆盖窗口。

卡库使用安静的原生墨绿面板；四列卡牌缩为 158×196，1152×648 下可完整显示两排。卡牌图像复用项目的植物和技能图标，属于主题示意图。选中边框、悬停与禁用按钮采用固定几何样式。右侧分为卡牌档案、当前卡组、光能分布；费用图根据草稿实时更新。保存、清空、恢复、补全、筛选、解锁及移除逻辑保留。

验证：

- `tests/test_deck_builder_runner.gd` 通过模型及 UI 测试，包括添加/移除、解锁确认、中文文案、两排布局、选中状态与真实纹理加载。
- `mm_manifest.py validate art_source/manifests/deck_builder.json` 通过。
- Godot 实际 OpenGL 运行完成并捕获 `art_source/evidence/deck_builder_runtime.png`。卡面为 158×196，库面板 738×484，保存按钮 180×48。
- 全项目测试仍报告战斗 HUD 契约和旧九宫格内容边距错误；卡组独立测试通过。Godot 启动还报告系统证书存储读取失败，不影响此次 GDScript 测试及图形捕获。

资源清单记录新背景路径、生成模型、提示词及实际尺寸；简单面板、卡框和按钮关闭图片生成，改用 `scripts/deck_builder_style.gd`。
