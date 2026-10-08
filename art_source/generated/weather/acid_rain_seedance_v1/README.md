# 酸雨视频转帧素材

- Provider: 火山方舟 Seedance `doubao-seedance-2-0-mini-260615`。
- 原始视频：`acid_rain.mp4`，5.041667 秒，960×960，24 fps，121 帧，无音频。
- 运行前处理：FFmpeg 等比缩小至 480×480，保留原始帧率与完整时长。
- 抠底：`aiskill/mm-tools/seedance_weather_frames.py` 调用 sprite-gen 的 `video.frames` 与 `frames.extract.remove_chroma_background_ycbcr`。视频将洋红底画成粉色渐变，因此显式使用色度抠底，参数 `flood_tolerance=24, chroma_in=12, chroma_out=42`。透明像素 RGB 清零。
- `frames_runtime/frames.report.json` 保存逐帧透明率及边缘检查。
- `loop_runtime/acid_rain.loop.report.json`：sprite-gen `video-loop --cycle fixed --start 0 --length 55 --fps 24 --strip-height 128 --anchor none`。取第一次完整下落、撞击、涟漪消失及一帧空白；循环 2.2917 秒，55 帧。固定区间由视频人工检查选定，接缝比率 1.023。
- 输出 strip：7260×128，每格 132×128；GIF 和 WebP 也经 sprite-gen 输出验证。
- 运行资源复制至 `assets/effects/weather/`，不改动 strip 或帧元数据。
- `scripts/acid_rain_fx.gd` 在世界空间中分散播放独立相位动画，仅绘制可见范围，不覆盖 HUD。
- `scripts/game.gd` 在酸雨夜启用；天候封印、白天、其它天气、胜负与撤退阶段停用。原有酸雨伤害逻辑保留。
- 生成脚本仅从进程环境 `ARK_API_KEY` 读密钥；报告不包含密钥或下载签名 URL。

验证：`tests/test_acid_rain_fx.gd` 检查资源加载、第三夜天气、酸雨伤害、封印暂停/恢复、天气切换、结束与重开。
