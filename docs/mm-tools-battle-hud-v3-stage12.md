# 战斗 HUD V3 阶段 1 / 2

2026-09-30，master；保留主界面和全部已有资源。只优化战斗常驻 HUD，保留游戏信号、快捷键、状态来源、母花强化和结算。

## 阶段 1

基线由 `tests/battle_ui_v3_capture.gd` 实际运行 Godot 捕获，1280×720：`tmp/battle-ui-v3-baseline/hud-day-runtime.png`、`hud-night-runtime.png`、`hud-mother-choice-runtime.png`。发现旧按钮图在宽高比变化后成为狭窄贴片，部署卡图端帽互相侵入，母花框视觉不完整，能量不足费用需要独立区域。

商业布局证据：2026-09-30 实际联网读取两个 Steam 页面，HTTP 200，标题分别为 Thronefall / They Are Billions。页面及前三张公开图保存在 `tmp/battle-ui-v3-research/`；商店前几张推广图隐藏 HUD，不能用这些图臆测实际界面细节。具体 UI 结构采用项目已存在的批准研究 `docs/superpowers/specs/2026-09-29-battle-hud-redesign.md`，并根据联网核验的玩法范围适配：Thronefall 的昼夜分阶段、防线构筑与战斗切换适配同一托盘的阶段内容；They Are Billions 的资源建造与能源网络适配固定资源读取和工具分组。区别：本项目含战斗卡牌，不复制 RTS 密集工具栏。外部案例仅布局与交互，不是美术依据。

项目风格证据：`Design/Sunflower-Defense-Art-Style-Guide.md`；运行时资源包括母花 healthy、thorn/prism/repair 图标、旧黄铜主操作框和圆仪表框，均完整列于 manifest style.evidence。视觉锚点是深墨绿安静面板、细氧化黄铜线、暖金生命条、上左软光、稀疏植物边纹。禁止高饱和、霓虹、大范围辉光、频闪、高频纹理、摄影、像素风；文字与动态数值由 Godot 绘制。

布局：顶部生命 / 阶段 / 资源使用一致暗绿平面和阅读层级。底部部署卡使用安静原生卡面，图标 / 名称 / 费用不被端帽侵入。右下唯一主动作宽标题并将费用固定在下半部；左下选择详情移到操作带上方。圆战术仪表保留网络和威胁功能。手牌按数量调整宽度。通知按需 2.5 秒退场。

## 阶段 2 生成确认计划

SSoT：`art_source/manifests/battle_hud_v3.json`；schema 1。生成只请求两张 gpt-image-2 / mm-api：`primary_action_frame` 512×384 真透明主操作框；`tactical_bezel` 512×512 真透明仪表框。主操作四态由同一母版调色、压暗派生，保持 alpha 和轮廓一致，不增加模型调用。路径使用新 `battle_hud_v3`，无覆盖旧资源。原生面板、按钮卡面、生命条、字体和保留模态资源均关闭生成。

运行接入读取同一个 manifest，缺图时保留完整可用原生界面。待用户确认生成批次后才能调用；当前阶段不生成、不提交。

## 阶段 2 验证结果

`mm_manifest.py validate` 通过，`plan` 展开恰好 2 项。`tests/test_battle_hud_v3_runner.gd` 通过：1152×648、1280×720、1920×1080 昼夜边界，五卡不与主操作重叠，底部保留 18px，shortcut/title/cost 分行，昼夜可见性、禁用/恢复、动作/卡牌信号、三张母花选择与通知退出。实际运行临时 UI 图为 `tmp/battle-ui-v3-layout/hud-day-runtime.png`、`hud-night-runtime.png`、`hud-mother-choice-runtime.png`；阶段 3 尚未开始，缺失两生成图的 warning 为预期兜底检查。

HEAD 基线与更改后实际分别运行原 `tests/test_battle_hud.gd`：两者均为同一 7 项既有失败（未实现 v2 `set_visual_state`、`BattleUiRoot`、`PauseOverlay`、`ResultOverlay` 与 result overlay 行为），更改无新增失败。比较脚本 `tmp/battle_ui_compare_runner.gd`。新增测试发现旧 `show_combat_hand` 单行条件导致 signature/清理未执行，连续刷新叠加卡牌；已明确多行更新、移除旧子节点后排队释放，防止实际战斗每帧刷新产生无限卡牌。原有缺失的 v2 结果弹层为独立旧问题，本次未宣称全套原测试通过。

实际截图审查修正两项临时实现问题：快捷提示改为非 Container 的 CostOverlay 子节点，避免被 PanelContainer 拉到标题中央；内托盘取消重复边距，外框高度改为 126px，杜绝底部越界。修正后重新运行全部上述检查并重拍截图。
