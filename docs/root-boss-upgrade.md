# 第五关根冠巨像：机制实现与小样进度

## 已实现

在现有工作区增量接入砸地、缠根、连续灯光压制、打断暴露窗口、阈值召唤队列及狂暴。砸地锁定最近存活植物（无植物时母花），1.2 秒蓄力，112 半径、22 伤害，仅逻辑落地事件结算一次。缠根半径 125、3.5 秒、攻击间隔乘 1.2，同类区域不叠加。

母花、连接光节点和连接临时光芽覆盖累计 3 秒后暴露 3 秒；离开清零，多光源不加速，结束冷却 8 秒。承伤倍率沿用 1.35。时间停滞与母花能力共用打断入口，取消待结算伤害及预警，时间停滞保留 0.6 秒控制，触发 2 秒暴露，重复打断不刷新。

75%、50%、25% 阈值各排队召唤两只枯壳撞兽，低血量狂暴，暴露期间暂停新技能。接入所属预警、区域、根卫清理，Boss 血条、蓄力提示和暴露倒计时。可选 Boss 动作兼容普通怪物四状态 manifest，落地动画时间映射不参与伤害结算。普通怪物减速卡生效时同步使同帧速度缓存失效。

## 验证与演示

`output/root-boss-tests.log`：40 项专项检查和 units/cards/fog 回归通过，覆盖第七关现有 Boss 的相关单位契约；不是第七关完整实战验收。

`output/root-boss-animations.log`：MONSTER ANIMATIONS PASSED。`output/root-boss-weather.log`：WEATHER_MODIFIER_TESTS_PASSED。

Godot 专项测试仍报告退出时 12 个 ObjectDB 实例未释放，以及 Windows 根证书存储读取错误；这些并未使检查失败，但不能宣称日志完全无警告。

`output/root-boss/normal.png`、`slam.png`、`impact.png`、`exposed.png`、`enraged.png` 为实际游戏渲染的机制场景。`mechanism-demo.mp4` 为 6.43 秒机制展示；`full-fight.mp4` 为完整确定性布防测试战斗（含准备和结束共 16.27 秒），战斗结果 `fight-result.json` 记录 Boss 在 11.17 秒被击败。该次战斗记录了三次召唤；砸地在独立机制演示中展示。它不是玩家手动游玩的完整第五夜录像。

## 写实小样 v2

经明确授权后，已新增一次原画请求并成功生成：`art_source/generated/root_boss_sample_v2/original.png`。原画通过初步人工检查：完整双臂双腿、枯枝王冠、湿润岩层树皮和琥珀核心可辨，纯绿背景边缘清晰。

火山任务已成功完成：任务 ID `cgt-20261006100340-pwcjz`，5 秒、720p、24 FPS，状态记录在 `art_source/generated/root_boss_sample_v2/slam.status.json`。原始视频为 `slam.mp4`；去背景逐帧结果为 `frames/keyed/`，共 121 帧，透明边缘无画面外接触，溢色材料占比 0.296%。

`loop-pinned/slam.gif`、`slam.webp`、`slam.strip.png` 和 `slam-preview.png` 已生成透明预览，使用脚底对齐。视频画面能看到抬臂动作，但自动 `one-shot` 检测未确认完整“离开待机并回到待机”的动作周期，因此没有把它发布成正式 Boss `slam` 状态；`loop-fixed` 和 `loop-pinned` 仅作为审阅证据，不能宣称伤害时刻已通过一帧误差验收。游戏仍使用占位造型，避免把未验收素材接入战斗。

这次失败属于动作质量门禁，不是接口失败，也没有重复提交视频任务。若继续，需要基于现有任务结果人工确认动作是否可接受，或在授权后重新提交一条明确夸张的砸地动作；原画不需要重建。

## 指定服务与续查

继续使用 `https://newapi.oairegbox.cc/` 的 `gpt-image-2`，火山 Ark 的 `doubao-seedance-2-0-mini-260615`，不切换服务。密钥仅通过进程环境传入，不写入脚本或任务记录。

原画在 `art_source/generated/root_boss_sample/image.intent.json` 留下本地提交记录：`da010f8d-f5fb-48ae-94d8-52cd18b9c099`。这不是服务端任务 ID。没有原画或结果报告，创建结果不明，禁止重复提交。尚未提交视频，因此没有视频任务 ID。

使用 sprite-gen 专属解释器运行 `art_source/root_boss_sample.py status` 查看本地状态；若后续存在 `slam.task.json`，该命令以 GET 续查视频任务，不创建新任务。当前没有服务端 ID，无法据此查询第三方原画结果。只有核清原请求状态后才能安排新的付费创建。

素材可继续的顺序：恢复并验收原画 → video-canvas → 单次 5 秒砸地视频 → video-frames 去背景去溢色 → video-loop one-shot、feet 对齐、保留源 FPS → 原画/透明帧小样/游戏内写实演示 → 用户确认 → 其余动作批量生成。批量动作目前没有启动。

专项复现：Godot `--headless --path . --script tests/root_boss_verification.gd`；普通动画回归：`--headless --path . --script tests/test_monster_animations.gd`。场景捕获：`--path . --script tests/root_boss_capture.gd`，追加 `-- --fight` 运行布防战斗。
