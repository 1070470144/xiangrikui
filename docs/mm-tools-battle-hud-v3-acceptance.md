# 战斗 HUD V3 四阶段验收

日期：2026-09-30；分支 master；未提交或推送。范围：战斗常驻 HUD；主菜单、游戏数值和旧资源不覆盖。

## 阶段 1：定位与布局，通过

依据和原图在 `docs/mm-tools-battle-hud-v3-stage12.md` 与 manifest `style.evidence`。基线实际运行图：`tmp/battle-ui-v3-baseline/hud-day-runtime.png`、`hud-night-runtime.png`、`hud-mother-choice-runtime.png`。原布局主要问题是卡牌旧装饰压缩文字、生命框缺安静底、主动作文字像贴片。新布局保留稳定边缘锚点与中心战场空间，生命/资源/阶段层级一致，四张部署卡分别可读，主动作快捷键/标题/费用分行。外部研究仅布局；两商业页面实际联网核验、具体分析复用项目批准研究。

## 阶段 2：Manifest 与功能，通过

`art_source/manifests/battle_hud_v3.json` schema 1 是资源与绑定唯一来源。`mm_manifest.py validate` 与 plan 通过；展开两项生成，面板、卡面、文字使用 Godot。阶段 2 临时图在 `tmp/battle-ui-v3-layout/`。新增行为测试三尺寸通过。现有原 HUD suite 实跑 HEAD 与当前各同一 7 项旧 v2 未实现契约失败，无新增失败，详见阶段 12 记录。

## 阶段 3：生成与实际接入，通过

用户确认后实际只调用两次 `mm-api / gpt-image-2`：`primary_action_frame`、`tactical_bezel`。源文件和原始 raw 及 sprite-gen 报告完整保留在 `art_source/generated/mm_tools/battle_hud_v3/`；无密钥生成侧报告。`mm_manifest.py verify` 通过。

原始模型画布均 1254×1254，主按钮真正艺术 bbox 为 `[66,393,1189,848]`（横向约 2.5:1），仪表 bbox `[119,95,1133,1119]`。不采用把 square 或横框整体拉伸到按钮的结果。`art_source/process_battle_hud_v3.py` 从 raw 取真实 alpha bbox，按钮角部等比缩到边界 <=18% 的区域，九宫格只扩展安静中心与直边，输出实际使用的 160×114 四态；仪表框等比 fit 到 512×512。Runtime 路径、size、margins 与四态 bindings 在同一 manifest。四态 alpha SHA256 完全一致；中心 opening alpha 为 0，网络与威胁环仍可见。派生报告 `art_source/generated/mm_tools/battle_hud_v3/derivation_report.json`；`process_battle_hud_v3.py --check` 通过。

同组审查：深墨绿底、氧化黄铜、稀疏植物纹、上左柔和暖光一致；文字区域安静，无水印/生成文字/大辉光。按钮四态只改亮度和饱和度；正常与 hover 可用，pressed 深入，disabled 降亮去饱和。实际 Godot 对两按钮全部四态 `StyleBoxTexture.texture.resource_path` 和仪表贴图路径断言通过，缺图兜底没有被删除。

## 阶段 4：对比与修正，通过

实际运行截图在 `output/imagegen/previews/battle-hud-v3-<resolution>-<state>.png`，resolution 为 `1152x648`、`1280x720`、`1920x1080`；每种都有 `hud-day-runtime`、`hud-night-runtime`、`hud-mother-choice-runtime` 和四态 `battle-hud-primary-normal/hover/pressed/disabled`。与阶段 1 原图在同一记录引用，不用静态合成代替运行结果。

符合项：原风格暖金生命与墨绿玻璃保持；中央母花与战場无遮挡；部署卡图标/名称/费用分离；夜战卡牌、选中态、不足资源和威胁可识别；圆仪表中心透空，实际网络和 BOSS 可见；主动作 Enter 入夜 / Space 施放对应真实 project.godot 输入；母花三选一保留。三尺寸无越界，五卡不侵入主动作，操作带底部保留 18px。

修正记录：①原生 PanelContainer 拉伸快捷提示导致标题重叠，移到 Control 叠层；②重复边距导致手牌下框越界，清除内边距并设 126px 外托盘；③第一轮生成接入 512px 纹理九宫格的 92px 角部超过 148px 按钮可用宽，出现圆贴片/硬切，拒收后返回阶段 3，将 runtime 派生为160×114并设置30×23角切，再重做三尺寸运行截图与全部行为测试；④旧单行 if 的手牌签名/清理不执行导致每次刷新叠卡，拆成清楚语句并立即移出旧节点，反复昼夜与尺寸切换验证。

最终 `tests/test_battle_hud_v3_runner.gd` 输出 `BATTLE HUD V3 CHECKS PASSED`；检查三尺寸昼夜、五卡边界、文字三层间距、动作与卡牌信号、能量禁用/恢复、三张母花强化、通知超时，以及实际生成贴图绑定。实际运行只留机器既有证书存储提示，无 HUD 资源缺失或布局警告。编辑器导入阶段机器没有 .NET SDK、既有临时 main-menu wav 有错误；本项目 HUD 为 GDScript，实际目标运行、导入新贴图、测试与截图均完成。

任务范围内无未处理差异。原 suite 的 7 项旧 v2 弹层/API 失败未由本次变更新增，未宣称旧全量 suite 通过。
