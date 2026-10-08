# Battle HUD 生成美术接入验证

## 范围

本记录覆盖 Battle HUD 的 mm-tools 阶段 1–3：项目风格证据、Manifest 与生成计划、生成图逐项验收、Godot 发布与实机接入。阶段 4 的完整多分辨率/多交互状态上线验收留待 Task 5。

## 阶段 1：布局与项目风格依据

- 保持既有 Battle HUD 布局与交互，不在本阶段重排控件。
- 项目风格来自 `Design/Sunflower-Defense-Art-Style-Guide.md` 及既有 day/night Godot 运行截图；外部商业案例仅用于既有信息层级参考。
- 统一视觉锚点为深墨绿半透明表面、氧化黄铜细边、克制的向日葵暖金高光与低噪声植物雕纹。

结论：阶段 1 通过；本次只替换正式美术皮肤，不改变功能结构。

## 阶段 2：Manifest 与生成计划

- 正式 Manifest 校验通过。
- 正式生成计划为 9 个有效 job：主按钮 `normal/hover/disabled` 三态、独立 `primary_action_button_pressed_single`、操作托盘、母花状态框、战术仪表框、开始守夜图标、太阳爆闪图标。
- 旧 `primary_action_button_pressed.png` 是四方案拼图，保留源图、raw 图和 report 作为生成证据，但已从 `states`、正式 build jobs 和运行时绑定中排除。
- 独立重做 `primary_action_button_pressed_single.png` 是单一按钮构图，保留安全区且尺寸、透明通道与九宫格边界符合契约，验收通过。
- Python manifest 精确断言覆盖 9 jobs、pressed 独立绑定，以及旧拼图不得出现在 build jobs。

结论：`validate`、`plan`、`verify` 均通过；阶段 2 通过。

## 阶段 3：逐图结论与 Godot 接入

| 资源 | 结论 |
| --- | --- |
| `primary_action_button_normal.png` | 通过；单一横向按钮、中心安静、轮廓清晰。 |
| `primary_action_button_hover.png` | 通过；与 normal 轮廓一致，高光差异可辨。 |
| `primary_action_button_disabled.png` | 通过；降饱和但仍保持边界可辨。 |
| `primary_action_button_pressed.png` | **拒绝**；四方案拼图，只保留生成证据，禁止运行时使用。 |
| `primary_action_button_pressed_single.png` | **通过**；单一 pressed 构图，绑定两个主操作按钮的 `theme_override_styles/pressed`。 |
| `phase_action_tray.png` | 通过；宽浅边框，中心未烘焙文字或控件。 |
| `compact_status_frame.png` | 通过；横向状态框，无伪文字，紧凑显示清晰。 |
| `tactical_instrument_frame.png` | 通过；圆形边框保持圆度，无方向字母或雷达点。 |
| `start_night_icon.png` | 通过；单一暮色温室图标，无按钮底板。 |
| `sunburst_icon.png` | 通过；单一向日葵爆闪图标，无文字与水印。 |

源图与生成报告保存在 `art_source/generated/mm_tools/battle_hud/`。由于 `art_source/.gdignore` 不参与 Godot 导入，正式 PNG 发布至 `assets/ui/generated/battle_hud/`；运行时 loader 按该既有映射加载，并保留源图与报告供追溯。

Godot 导入完成后，test runner、integration smoke 与 startup 均无缺失 Battle HUD texture 或无效 binding。九宫格纹理保留 patch margins，同时显式使用零 content margins，避免生成素材把现有控件最小尺寸撑大。实机截图：

- `output/imagegen/previews/battle-hud-day-final.png`
- `output/imagegen/previews/battle-hud-night-final.png`

逐图检查确认正式生成 skin 已显示；按钮只呈现单一构图，没有旧 pressed 拼图；面板与按钮边缘连续，无九宫格拉伸畸变或因纹理 content margins 造成的遮挡。

## 阶段 3 上线修正（2026-09-30）

撤回上文“原始四态轮廓一致”和“tray/status 九宫格边缘已正确显示”的结论。复核发现四张模型输出的 alpha bbox 不同，且 `phase_action_tray.png` 上方 70 像素为透明留白，旧 patch margin 落在透明区；夜间按钮同时由 Button 排布图标/标题并叠加费用标签，存在重叠风险。

修正后，原始模型 PNG、raw PNG 与 report 均原样保留为审计证据。`art_source/process_battle_hud.py` 以批准的 normal 按钮为唯一轮廓/alpha 基准，确定性派生同构 normal/hover/pressed/disabled 四态；tray/status 按 alpha bbox 加 8px 安全边距紧裁。Manifest 的 `output` 继续描述模型源输出，新增 `runtime` 明确绑定派生文件、真实尺寸、九宫格边距与派生脚本，未将派生图虚报为模型输出。

夜间主按钮缩短为“爆闪”，图标上限 36px，费用位于独立底行。真实 1152×648 SubViewport 自动化验证费用行位于按钮内且在上方内容区之后。交互态实机证据：

- `output/imagegen/previews/battle-hud-primary-normal.png`
- `output/imagegen/previews/battle-hud-primary-hover.png`
- `output/imagegen/previews/battle-hud-primary-pressed.png`
- `output/imagegen/previews/battle-hud-primary-disabled.png`

更新后的 day/night 实机证据为 `battle-hud-day-final.png` 与 `battle-hud-night-final.png`。阶段 3 的旧错误结论已由本节取代；最终结论以本节列出的自动化与实机证据为准。
