# 战斗场景可读性优化验证

日期：2026-09-30

## 实现结果

- 八方向威胁数据继续使用 `BattlefieldSpec` 的真实入口映射，显示位置投影到母花周围 380 世界单位的可视环，避免入口位于镜头外导致提示不可见。
- 普通、高危、首领分别使用不同强度、色彩和外轮廓；提示为纯 `Node2D` 绘制，不创建输入或碰撞节点。
- 母花增加安全、近域威胁、受击、低生命四种世界状态环。
- 顶部普通通知缩至 360×36，显示时间从 4 秒降到 2.5 秒。
- 无威胁时战术仪表透明度降至 0.38，有威胁或首领时恢复完整强调。

## 自动验证

命令：

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/integration_smoke.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --quit-after 120
```

观察结果：`TESTS PASSED`、`INTEGRATION PASSED`，三个进程退出码均为 0。环境仍存在基线中的 `user://logs` 不可写提示；它在修改前已存在，不影响退出码。

## 1152×648 实机捕获

- `output/imagegen/previews/readability/01-day-idle.png`
- `output/imagegen/previews/readability/02-night-normal.png`
- `output/imagegen/previews/readability/03-night-severe.png`
- `output/imagegen/previews/readability/04-boss-threat.png`
- `output/imagegen/previews/readability/05-mother-hit.png`
- `output/imagegen/previews/readability/06-mother-critical.png`

目视检查确认：零威胁时右侧仪表退居次级；东北普通来袭和东方高危来袭可直接从世界提示判断；首领增加独立金色外环；受击为短促亮环，低生命为稳定红色环；提示没有覆盖母花、底部卡牌或部署中心区。

## 已知限制与下一问题

- 当前威胁提示读取的是生成队列聚合强度，不表示已经进入战场的单个敌人精确位置。
- 本轮没有为缺少权威预告数据的攻击伪造地面范围。
- 下一轮最值得验证的问题：实际高密度多方向夜战中，多个同时提示是否仍能在一秒内分辨主次。
