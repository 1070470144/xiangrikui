# 怪物帧动画接入

## 五只怪物的视频动作（2026-10-03，第二批）

本批使用用户指定的 `gpt-image-2` 网关制作蚀芽虫与三个独立外形的参考图，使用火山方舟 `doubao-seedance-2-0-mini-260615` 生成动作视频，再通过 sprite-gen 2.11 的 `video-canvas`、`video-frames`、`video-loop` 提取透明帧。影兽攻击复用上一批视频中的角色外形。生产脚本 `art_source/monster_video_batch.py` 仅从进程环境读取 `OPENAI_API_KEY`、`ARK_API_KEY`，不会保存凭据或视频签名地址。

运行时增加枯壳撞兽、腐孢蛾和黑甲育虫动画资源加载。这三个沿用既有怪物配置、能力和波次，分别从第 2、3、5 夜出现。每只均有移动循环和一次完整攻击（蓄力、出击、恢复）；腐孢蛾移动为振翅飞行，攻击为振翅与卷腹动作，腐蚀伤害继续由原游戏逻辑处理。

移动使用源视频 24 FPS，减速仅改变相位推进速度。攻击保存原始帧顺序与源帧率，实际播放时沿用原有攻速限制：播放时长为 `min(源帧数 / 源FPS, 攻击间隔 × 0.8)`，因此预览视频与游戏内攻击速度有差异。伤害结算时机和攻击间隔保持既有逻辑。每个动作的独立画布、透明边距与地面坐标通过 manifest 加载，飞行怪另有悬浮高度；眩晕现在同时冻结画面、攻击时钟和剩余动作时长。

源视频、透明序列、GIF/WebP、原始帧率、检测报告、人工接触表检查记录和旧运行资源备份均保存在 `art_source/generated/monster_video_batch/`。`publish_monster_videos.py` 只发布工具检查通过且有人工验收记录的序列。移动中的蚀芽虫、腐孢蛾、黑甲育虫实测周期 1.7–2.1 秒，检测窗口显式扩到 60 帧；未提高周期性或接缝阈值。腐孢蛾按翼拍的 flight profile 检测，其他地面怪按 walk profile。

越界视频和黑甲育虫口器变形候选保留在各角色 `rejected-*` 目录，未发布。当前动作为 AI 生成的风格化表现；周期检测和逐帧外形检查不证明每只脚的接触与受力符合真实生物力学。枯壳撞兽攻击少量帧保留小型冲击环。

| 怪物 | 移动帧数 | 攻击帧数 | 源帧率 |
| --- | ---: | ---: | ---: |
| 影兽 | 15（保留上一批） | 51 | 24 FPS |
| 蚀芽虫 | 41 | 51 | 24 FPS |
| 枯壳撞兽 | 37 | 50 | 24 FPS |
| 腐孢蛾 | 50 | 46 | 24 FPS |
| 黑甲育虫 | 50 | 56 | 24 FPS |

腐孢蛾在停止移动时仍持续播放悬浮振翅，眩晕时冻结。`game-preview.gif` 使用发布到游戏的 PNG、运行尺寸与攻击时长生成两倍显示的动作总览。

本批验证：Godot 导入成功；`test_monster_animations.gd` 五只怪物的帧加载、帧率、相位、攻击恢复、地面/悬浮锚点、眩晕与飞行检查通过。`content_system_smoke.gd` 的十种怪物生成与内容断言通过，但启动时报告酸雨 `acid_rain.strip.png` 及其 JSON 缺失。`integration_smoke.gd` 仍在夜间种植能量消耗断言失败，也报告相同酸雨资源问题。该全局检查未通过；本批没有修改天气资源和种植能量逻辑。

## 影兽视频序列帧（2026-10-03）

影兽移动已替换为 Seedance 视频经 sprite-gen `video-frames` → `video-loop` 提取的透明序列。源视频 121 帧、24 FPS；选取源索引 46–60 的 15 帧周期，按 24 FPS 播放（0.625 秒）。自动 motion-auto 对齐，循环接缝比 1.5516，默认上限 2.0；未提高阈值、补帧或倒放。逐帧检查可见四足收拢、伸展、腾空和回收，实际动作更接近奔跑。报告建议人工复查，像素周期检测不能证明每只脚的解剖动作或落地接触正确。

完整视频、透明帧、循环 GIF/WebP、接缝报告和接触表位于 `art_source/generated/monster_video_ark/shadow_beast/`。通过 canonical strip metadata 输出 252×140 帧，仅增加透明边距为游戏使用的 252×192 帧，身体参考高度 123、共用地面 y=178，保持既有缩放。原影兽移动资源与 manifest 备份于该目录的 `previous-game-walk/`；复现发布使用安装技能的 Python 运行 `art_source/integrate_shadow_video.py`。

本次只接入已有视频的影兽移动。影兽攻击和蚀芽虫仍使用下面记载的 8 帧版本。停止时保留当前帧一个渲染步骤的逻辑已修正；测试涵盖新帧数、原始帧率、完整画布、减速相位、收步、攻击与眩晕。

本次验证：Godot 导入成功，`test_monster_animations.gd` 通过。全局 `integration_smoke.gd` 在“夜间应急芽消耗 23 点能量”断言失败；本次没有修改种植和能量逻辑，该全局检查不能标记为通过。

## 之前的图片序列版本

当前移动资源已更新至 `art_source/generated/monster_gait_v3/`：影兽按四足交替步态、蚀芽虫按昆虫交替支撑组重做。被拒收的蚀芽虫爪形候选保存在该目录内，未接入运行资源。原八帧版本保留在 `monster_animations/`。本版保留攻击资源，同时修复移动受减速影响时的帧相位跳变、攻击提前截断恢复帧的问题。

运行时又增加了收步保持：怪物停止移动的第一帧保留当前落脚姿势，下一帧才回到中性帧，避免腿部突然换位。减速和加速只改变相位推进速度，不重算当前帧。

使用 sprite-gen 2.11 的 component-row 流程，调用用户指定的 HTTPS 网关与 `gpt-image-2`。
影兽、蚀芽虫各有移动 8 帧（12 fps，循环）与攻击 8 帧（12 fps，单次）。透明帧为 192×192，厚涂绘本风。相比上一版，邻帧姿势跨度更小，移动和攻击都更连贯。

运行资源：`assets/enemies/animations/`。`scripts/monster_animation_library.gd` 按 manifest 中的帧数、速度与循环标记缓存加载。`enemy.gd` 在移动时推进动画、攻击时从首帧播放，停止时保持中性帧，眩晕时冻结；目标在左侧时水平翻转。保留受击闪光与现有伤害结算时机。

此批只覆盖影兽、蚀芽虫。其他敌人继续使用原有资源。

生成源、原始行、提取报告、图集及 GIF 位于 `art_source/generated/monster_animations/`。上一版 4 帧移动行因腿部变化太小被拒收；本版重新生成 8 帧相邻过渡，使用交替迈腿版本。

本版四条 8 帧动画行均有完整生成报告、透明提取、图集和 GIF 检查报告。

验证：两套 extract 与 inspect 均无错误或警告。Godot `test_monster_animations.gd` 与 `integration_smoke.gd` 通过。导入日志中的 .NET SDK、旧音频与证书信息来自现有环境，未阻止 GDScript 检查。

重新生成：在进程环境设置 `OPENAI_API_KEY`，使用安装技能的 `.venv/Scripts/python.exe` 运行 `art_source/generate_monster_animations.py`，依次执行 `prepare`、`generate`、`finish`、`publish`。已存在的行默认复用。凭据不写入生成脚本或项目配置。发布前应检查 `qa/` 动作预览。

