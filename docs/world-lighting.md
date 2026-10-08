# 昼夜光照

`scripts/world_lighting.gd` 是世界光照的唯一阶段控制器。`set_phase(day, transition_seconds = 1.5)` 从当前亮度以 smoothstep 插值到目标；`get_lighting_state()` 返回昼夜强度、太阳方向、太阳色、环境色、阴影与反弹光强度。重开立即恢复白昼，白昼、夜晚、胜利和失败使用同一阶段接口。

太阳方向表示光线投射方向，默认从左上向右下，不模拟实时太阳轨迹。白昼是暖色侧光，夜晚是冷蓝灰环境光。光脉节点与母花使用平方距离衰减的暖光池；损坏或断连的节点停止供光。首版最多支持 32 个同时有效的光源。

地面 shader 使用 MODEL_MATRIX 拼接 TileMap 象限的世界坐标，并减去 world_origin 采样现有连续纹理。镜头平移和缩放不会改变采样坐标或光源位置。地面纹理的亮度差用于微弱浮雕明暗；bounce_strength 是绘画式反弹光近似，不是物理光线追踪。沼泽和酸雨图层保留独立素材颜色及透明度，再叠加环境受光。

地面接触阴影层位于地形上方、角色下方。不同类型对象使用不同半径和估算高度，生成与太阳同方向的柔软投影；夜晚投影缩短并减弱，脚下保留冷色接触阴影。接入身体 shader 时主动重绘，清除缓存中的旧黑圆，避免两套阴影叠加。高度是按对象类型估算的绘画近似，不读取三维几何。

角色根节点及其 Sprite2D / AnimatedSprite2D 身体共享受光 shader，保留 powered/unpowered 和受击 modulate。程序绘制身体也接受受光；独立血条、特效和 CanvasLayer HUD 不继承身体 shader。统一控制器不修改战斗数值。

daylight_glow 读取统一强度、方向和太阳色；night_fog 只叠加天气雾和视野遮蔽，天气启停也逐渐过渡。调整画面时优先修改 world_lighting 的日夜颜色与强度，其次修改阴影层的类型半径和高度。

## 植物开拓浓雾

统一控制器每帧通过 `get_reveal_sources()` 收集存活母花、具有战斗供光的存活植物和已连接光网的存活节点，再交给 `night_fog.set_reveal_sources(sources: Array[Dictionary])`。每项包含对象实例 ID、世界位置和清晰半径。植物储能与低光阶段仍提供视野，休眠或死亡后停止；节点断连或损坏后停止。敌人不提供视野。

母花、植物和节点的清晰半径分别为 90、120、190 世界像素，外侧增加 60 像素 smoothstep 柔边。范围独立于攻击和供光范围。来源出现或消失以 0.5 秒淡入淡出，消失的来源只保留位置、半径和渐变数据；没有永久探索记录。重新供光可以从当前渐变强度反向恢复，重开调用 `clear_reveal_sources()` 立即清除旧视野。

视野使用覆盖整个战场的 288×288 R8 单通道纹理，以 20 Hz 更新；每个来源只计算圆形包围框中的像素，重叠取最大可见度，稳定后不再重建纹理。shader 使用世界坐标采样并线性过滤。此视野纹理没有地面照明的 32 光源上限；晴夜和白昼的浓雾启停仍由原有天气与光照规则控制，不影响战斗判定和 UI。

## 验证

在项目目录运行 Godot 4：

```powershell
& '<Godot_console.exe>' --headless --path . -s tests/world_lighting_capture.gd
& '<Godot_console.exe>' --path . --rendering-method gl_compatibility -s tests/world_lighting_capture.gd -- --capture
```

专用测试覆盖阶段切换、中途反向、强度范围、角色 shader 绑定、节点损坏、天气、结算与重开，以及镜头移动时地面采样参数和光源坐标保持稳定。实际渲染截图输出到 output/lighting：day、transition、night、night-broken、night-fog。

`tests/test_fog_reveal.gd` 同时加入完整测试入口和光照专项入口，覆盖半秒渐变、中途恢复、柔边、重叠、42 个来源、地图边界及清空。光照专项还验证储能、低光、休眠、节点断连、植物死亡、重开与镜头移动。扩张前后和供光变化截图为 fog-before-expansion、fog-expanded、fog-power-lost、fog-power-restored。2026-10-05 验证：光照专项 headless 与 OpenGL 捕获、地形测试及内容系统测试通过；完整 test_runner 仍因已有 HUD、相机与波次契约问题退出 1。

当前完整 test_runner 与 integration_smoke 尚有 HUD、相机、夜晚部署及波次契约失败，专用光照测试不能代替完整套件通过。首版只使用已有素材及运行时 shader，不依赖或保存任何外部生成服务凭据。
