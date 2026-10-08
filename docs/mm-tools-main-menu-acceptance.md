# 主菜单右侧 UI：MM Tools 阶段 4 验收

## 阶段 1：功能与布局

- 保留原有主菜单功能、账号入口、继续游戏、卡组、七夜记录、图鉴、设置和退出路径。
- 右侧定位为“温室园丁档案”：346×506 竖向面板、70px 主按钮、50px 次级目录行。
- 原生 Godot fallback 可独立运行；视觉方向记录于 `docs/superpowers/specs/2026-09-29-greenhouse-gardener-record-menu-design.md`。

## 阶段 2：Manifest 与临时 UI

- Manifest：`art_source/manifests/main_menu.json`。
- 视觉证据来自实际主菜单温室背景、Godot 运行截图和项目美术指南。
- 12 个生成任务使用新 `mm_greenhouse_*` 文件名，不覆盖旧卷册素材。
- 所有按钮声明中央低细节安全区，文字继续由 Godot 绘制。

## 阶段 3：生成与接入

- 12/12 资源由显式 `mm-api / gpt-image-2` 生成；报告无密钥、无 provider fallback。
- 原始生成保存在相邻 `.raw.png`，多候选画布经确定性裁切成为单一 UI 资源。
- Manifest verify 检查通过；运行时通过 `ArtManifest` 按显式节点路径绑定。
- 缺少或无效资源时保留原生 StyleBox fallback。

## 阶段 4：实际运行对比

最终 Godot 截图：`tmp/main-menu-review/greenhouse-final00000004.png`。

| 验收项 | 结果 | 证据与修正 |
|---|---|---|
| 与温室背景一致 | 符合 | 深墨绿低对比面板、细黄铜边与冷蓝温室形成统一材质语言。 |
| 信息层级 | 符合 | 园丁记录标题 → 继续守夜 → 进度 → 四个目录项 → 退出。 |
| 按钮舒适度 | 符合 | 主按钮 70px、目录项 50px，行间留白稳定。 |
| “继续守夜”文字区 | 符合 | 中央无场景插画或压缩图案，文字清晰。 |
| 状态素材 | 符合 | 主按钮和次级按钮均具有 normal/hover/pressed/disabled 四态。 |
| 禁止风格 | 符合 | 未使用卷轴、朱砂印章、中式牌匾、云纹或高密度金花纹。 |
| 功能与导航 | 符合 | 主菜单功能测试与布局测试通过。 |
| 资源绑定 | 符合 | Godot 捕获运行无 Manifest 节点缺失警告。 |

未处理差异：无。
