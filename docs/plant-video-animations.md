# 植物视频动画

十五种可选择植物各有待机、攻击／辅助、死亡和复活动作，共六十组状态。视频由用户指定的火山引擎 Ark `doubao-seedance-2-0-mini-260615` 生成，再由 sprite-gen 的 `video-frames`、`video-loop` 完成抠色、帧提取和条带导出。新版攻击和复活都是独立生成的新视频，复活没有倒放死亡素材。

## 素材与运行

- `assets/plants/animations/<species>/manifest.json` 记录帧数、原速 FPS、循环标记、每状态画布、固定根部偏移和原始证据路径。待机与死亡使用透明 160×160 PNG；新版攻击可使用 320×320 透明画布容纳藤蔓伸展，同时维持本体尺寸。根部相对画布中心的纵向位置都是 +59 像素。
- 每组源视频为四秒、无声音。待机和攻击首尾使用同一植物参考图；死亡新版只固定首帧；复活首帧来自真实死亡末帧、尾帧来自健康待机。新版攻击与复活各 15×64=960 帧，死亡共 480 帧。新版视频按真实 24 FPS 采样，规范条带合成器最多保留 64 帧，原速约 16 FPS；游戏按动作时长加速播放，不能把采样率当作导出帧率。
- `scripts/plant_animation_library.gd` 缓存 SpriteFrames 和固定动作偏移；`scripts/plant.gd` 使用 AnimatedSprite2D 播放待机和单次动作。攻击结束回到待机，攻击速度按游戏攻击间隔调整，低光时变慢，休眠时暂停。蜜露花治疗触发辅助动作，守灯花支援附近存活植物时触发辅助动作。
- 原静态图片保留为缺失动画时的后备。此次范围为十五种槽位植物，母花形态仍沿用已有实现。
- `scripts/plant_attack_fx.gd` 在本体动作触发时播放视频转帧的藤蔓、花粉和冰晶冲击；伤害仍由原战斗逻辑结算。
- 植物下方的程序化土壤遮罩已移除，避免出现纯色横条；根部直接显示在地图上。
- `scripts/mother_form_visual.gd` 为每个母花分支增加独立颜色、枝条数量和升级等级驱动的呼吸光环；升级后的母花会持续轻微摆动和闪烁。
- 母花常用动画由母花健康形态参考图生成四秒短片，经 sprite-gen `video-frames` 与 `video-loop` 转为 64 帧透明循环序列；游戏播放轻柔呼吸、中心能量脉冲和复位动作，静态母花图片保留为素材缺失时的后备。
- 白昼部署时间已由 22 秒延长到 45 秒，首次白昼由 30 秒延长到 45 秒。

## 生成与复查

`art_source/plant_video_ark.py` 保存任务 ID 后轮询，支持恢复任务，避免重复提交；密钥仅通过 `ARK_API_KEY` 进程环境传入。旧待机／死亡源视频在 `art_source/generated/plant_video_ark`；新版攻击／复活在 `plant_actions_video_v3` 和 `plant_attack_video_v4` 至 `plant_attack_video_v7`，最终每种状态的证据以运行 manifest 为准。生成目录用 `.gdignore` 隔离。

生成结果中出现过火焰越界、棱晶和蜜露根部偏移、刺棘攻击缩小。拒收素材保存在对应 `rejected-*` 目录，修改动作约束后重新生成。运行素材只使用通过检查的版本。

`art_source/plant_animation_review.py` 检查透明边界、隐藏底色、独立帧数量、根部位置稳定性和待机／攻击首帧尺寸衔接，并生成原速总览 GIF。视频帧经过 sprite-gen 的规范流程处理；运行适配只将规范条带帧填充到游戏画布。

## 验证

- 死亡序列：每种植物 32 帧，源视频取前 2.7 秒；初版排除首尾固定参考图造成的复原尾段，八种枯萎幅度不足的植物重做时取消存活尾帧约束。SpriteGen 使用 `--cycle fixed` 导出；死亡不循环，首尾接缝不作为死亡动作门槛，报告仍记录差异。运行 manifest 的 `loop=false` 才是 Godot 播放依据。
- 致死时立即停止战斗，保留可见节点并用约 1.1 秒播放死亡；不受休眠、低光影响。结束后隐藏并发出一次 `destroyed`。复活卡让至多三株植物进入独立 `revive` 状态，约 1.2 秒播放枯萎到健康的恢复动作，结束再回待机；期间不能攻击。死亡中途复活会取消旧死亡回调；复活期间再次致死会重新进入死亡。
- `art_source/review_plant_death.py` 输出待机、死亡首帧、中间和末帧对照图；`tests/test_plant_death_animation.gd` 验证 15 种死亡、重复伤害和中途复活。
- `art_source/review_plant_actions.py` 验证全部 45 组攻击／死亡／复活的源视频、SpriteGen 报告、非循环设置、独立帧、透明边界与首尾本体尺寸，输出 `tmp/plant-actions-preview.gif` 和 `tmp/plant-actions-review.json`。`tests/test_plant_resurrection_card.gd` 验证实际复活卡触发独立复活动画。
- `tests/plant_actions_capture.gd` 渲染 Godot 实际加载的新攻击、死亡、复活截图。更新素材后应关闭旧游戏窗口并重新运行，旧进程缓存的 SpriteFrames 不会自动刷新。

- 植物动画测试：十五种植物的实际动作完成、返回待机、暂停恢复和更换品种。
- 五槽植物扩展：46 项检查。
- 日夜流程：117 项检查。
- 母花形态集成：67 项检查。
- Godot 实际渲染截图：`output/imagegen/previews/plant-video-animations-1280x720.png`。

可重复执行：先运行 `plant_video_ark.py process` 处理已有视频，再执行 `plant_animation_review.py`，最后用 Godot 导入并运行 `tests/test_plant_video_animation.gd`。

新增效果也走同一条 sprite-gen 序列帧链路。通用转换器 `art_source/spritegen_sequence_pipeline.py` 会执行 `video-frames` 抠色和 `video-loop` 循环检查；例如藤蔓攻击素材：

```powershell
$py = 'C:\Users\刘冉\.codex\skills\sprite-gen\.venv\Scripts\python.exe'
& $py art_source/spritegen_sequence_pipeline.py `
  --clip art_source/generated/plant_video_ark/thorn_flower/attack.mp4 `
  --reference art_source/generated/plant_video_ark/thorn_flower/input-magenta.png `
  --out tmp/spritegen-vine-check --name vine --fps 12
```

该检查当前输出 97 帧源序列、64 帧循环序列，透明边界检查和循环报告均为 `passed`。运行时的藤蔓、花粉和冰晶冲击仍由 `plant_attack_fx.gd` 按目标位置触发，避免把攻击判定绑定到素材帧。

母花常用动画生成与发布脚本为 `art_source/mother_video_ark.py`，只从 `ARK_API_KEY` 环境变量读取凭据；序列素材发布在 `assets/core/generated/mother_animation`，帧清单为 `manifest.json`。重复运行会复用已保存的视频和 Ark 任务 ID。
