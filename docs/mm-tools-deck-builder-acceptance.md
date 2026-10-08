# 卡组配置 mm-tools 验收记录

## 阶段 1：功能定位与布局

- 沿用已完成的全屏卡组配置结构，不再进行布局优化或外部案例调研。
- 检查依据：1152×648 基准结构包含四列卡牌库、右侧详情、当前卡组、费用曲线及固定底栏；功能与交互测试均已存在。
- 原项目风格约束：深蓝黑与墨绿、氧化黄铜细边、暖金光能、末日温室植物档案册语汇。

## 阶段 2：Manifest 与功能

- Manifest：`art_source/manifests/deck_builder.json`。
- `mm_manifest.py validate` 与 `plan` 通过；23 项生成任务经用户确认。
- Python Manifest 测试 9 项通过；Godot 功能测试通过。

## 阶段 3：生成与接入

- 23/23 项由 `mm-api / gpt-image-2` 生成，报告未记录密钥。
- `mm_manifest.py verify` 通过：PNG、目标尺寸与透明通道符合 Manifest。
- 源图与报告保存在 `art_source/generated/mm_tools/deck_builder/`；运行资源发布至 `assets/ui/generated/deck_builder/`，避免 `art_source/.gdignore` 阻止 Godot 导入。
- Manifest 加载器接入背景、面板、按钮与装饰；卡牌组件按稀有度和状态加载卡框，并使用费用徽章与锁定图标。

## 阶段 4：逐项对比

- 最终截图：`tmp/deck-builder-mm-tools-final.png`（1152×648）。
- 布局：四列卡牌无重叠；右侧详情与卡组列表完整；顶栏、底栏和保存操作均在视口内。
- 信息层级：卡名、费用、阶段、稀有度、数量和规则反馈可读。
- 状态反馈：锁定、卡组已满、不可加入均有图标或文字，不只依赖颜色。
- 风格：温室夜景、暗绿纸面、黄铜框线和暖金高光与既定原项目方向一致。
- Manifest：所有 23 项输出均通过校验；静态资源由 Manifest 绑定，动态卡牌资源由组件根据卡牌数据绑定。
- 未处理差异：无。
