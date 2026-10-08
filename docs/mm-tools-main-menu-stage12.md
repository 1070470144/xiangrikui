# 主菜单 mm-tools 阶段 1-2 记录

## 阶段 1：功能定位与布局结论

主菜单承担本地档案入口、继续守夜、卡组配置、七夜记录、温室图鉴、设置和退出。现有实现已经使用右侧 346x506 的“温室园丁档案”面板承载菜单，主操作为 290x70，次级目录行为 290x50；标题、档案进度和目录操作形成稳定的从上到下阅读路径。测试 `tests/test_menu_layout.gd` 覆盖主操作焦点、页面跳转、返回、账号入口和减弱动态效果，因此本轮保持布局几何，仅提高证据可追溯性和材质/对比约束。

布局研究仅用于交互结构：Inscryption 参考单一主操作和次级目录分层；Into the Breach 参考紧凑状态摘要和明确返回路径。两者均不作为美术风格来源，也未复制品牌资产。

## 项目运行证据与视觉锚点

- `res://art_source/evidence/main_menu_runtime.png`：Godot 主菜单运行截图，默认首页状态，记录现有 1152x648 运行表现。
- `res://assets/backgrounds/ART_BG_MainMenu_Greenhouse.png`：废弃温室背景，提供冷蓝月光、深墨绿玻璃和左侧暖光主体基准。
- `res://assets/ui/generated/mm_greenhouse_record_panel_v2.png`：右侧档案面板，提供氧化黄铜细边、低对比旧档案纸和 346x506 几何基准。
- `res://assets/ui/generated/mm_greenhouse_primary_v2_normal.png`：继续守夜主操作默认态，提供 290x70 安全区和暖金焦点层级。
- `res://assets/ui/generated/mm_greenhouse_secondary_v2_normal.png`：目录行默认态，提供 290x50 高度和低对比底线。
- `res://assets/ui/UI_ICON_Repair.png`：项目运行时图标，提供小尺寸轮廓与暖金对比基准。

具体视觉锚点：深墨绿旧档案纸、氧化黄铜细边、暗色温室玻璃和克制暖金高光；中央控件区域低细节、文字由 Godot 字体绘制。舒适性约束为按钮高度不低于 50px、主操作高亮只服务当前焦点、中央保持低纹理密度、避免闪烁和厚重外发光。排除东方卷轴、朱砂印章、中式牌匾、伪文字、水印和按钮内场景插画。

## 阶段 2：Manifest 与生成计划

唯一事实来源为 `res://art_source/manifests/main_menu.json`，schema 版本 1。现有资源状态保留；未授权的付费生成阶段不执行。后续用户确认后，按 manifest 中启用的资源调用 `mm-api / gpt-image-2`，输出目录和节点绑定以 manifest 为准，并先执行 `validate`、`plan`、`generate --confirm`、`verify` 与 Godot 实际运行截图验收。

