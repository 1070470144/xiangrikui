# 卡组按钮 v6

参考昆特牌官方页面 https://www.playgwent.com/en/media#/screenshots 的金属边框、材质中心与主次操作层级。sprite-gen 使用已授权 gateway 与 gpt-image-2 生成两张原创按钮板：旧铜叶纹/深绿皮革次操作，金叶纹/深绿皮革主操作。中央纹理保持低对比，所有文字由 Godot 绘制。生成 prompt、raw、report 均保留；透明外沿已检查，sprite-gen chroma 后裁去空白边距，运行时192x48。

应用范围：返回、筛选、排序、清空、恢复、自动补全、保存、卡牌加入/查看、卡组移除、详情旋转/加入/关闭。四态使用同一纹理调色，焦点保留描边；避免各态重生成造成轮廓漂移。按钮两端用九宫格保护，中央皮革适应按钮宽度。

Godot headless 与图形模式测试通过；原生点击、翻面、旋转及双向拖拽通过。实机证据见 res://art_source/evidence/deck_builder_runtime.png 和 res://art_source/evidence/deck_buttons_detail_v6.png。workflow finish 暂不支持 openai provider 枚举，不伪报渠道或保存默认设置。
