# V6 世界拖拽预览验证

实现使用现有植物运行时纹理；原生 Sprite2D 半透明 ghost 不加入 plants/light_nodes 组，不执行任何攻击、扣费或网络写入。位置统一从实际 Viewport mouse position 经 canvas_transform.affine_inverse 转换，跟 release 使用同一世界坐标系。

`CardEffectResolver.get_target_preview` 为只读契约：引用 ContentData 卡牌半径与 TemporaryBattleObject 实际默认作用半径。根墙/诱光花苞160、引路灯标220为 resolver 同一常量；太阳地雷显示真实爆炸65和触发45两圈。缠根地带、日矢雨实际执行使用默认70，不按描述另造半径。单体牌只显示目标标记；全局牌以母花为提示中心、无有限范围圈；幻影开花 ghost 在实际可生成位置显示。

植物部署显示实际纹理、实际世界缩放及供光连线，光脉芽显示真实190供光范围。预算、供光、占地和阶段只读检查后以浅绿/红色反馈，松开后原有执行路径再次验证并扣费一次。cancel、modal、phase change、释放或回到UI时清理世界预览。

## Godot 实际运行证据

- `tests/test_drag_world_preview.gd`：headless 与实际 OpenGL 运行均 `DRAG WORLD PREVIEW PASSED (0 failures)`。测试通过 SubViewport.push_input 真实 mouse motion/button 原生拖拽链；冻结模拟后仅调用只读指针刷新，避免时间流逝改变测试场景。
- 植物 actual texture/0.58 scale/世界坐标，光芽190供光与预算不足反馈；7类范围与resolver值一致；单体敌人目标吸附/42damage；全局未提前cast；右键取消、modal、phase变化清除并且不消费。
- `output/imagegen/previews/battle-ui-v6-plant-drag.png`：1280×720 白昼，camera1.35真实种植ghost。
- `output/imagegen/previews/battle-ui-v6-invalid-plant.png`：同分辨率，母花阻挡区域无效红色。
- `output/imagegen/previews/battle-ui-v6-area-drag.png`：1280×720 黑夜，camera1.35显示缠根地带70世界范围圈。

运行器存在系统证书存储警告，不影响渲染/输入结果；最终有效运行没有 SCRIPT ERROR。早期monster animation脚本并发编辑期间产生的依赖编译错误轮次不列入通过证据。

## HUD 独立复核

`tests/test_fan_hover_independent.gd` 用1152×648五张重叠卡牌，对每张卡上方与底部可见区域执行实际鼠标hover，连续±1px微动且每次执行实际 `_refresh_card_ui`，验证抬起姿态持续保持；每张牌再执行native drag并返回手牌，不扣光能不消耗卡。

最初复核发现底部hover微动闪回，以及live refresh每帧重置抬起位置；由HUD负责agent修复 `_hovered` 姿态保存和 `_has_point` 当前卡面/原静止命中区联合判断。修正后全部5牌上沿、下沿hover及拖拽可达，`FAN INDEPENDENT HOVER PASSED`。
