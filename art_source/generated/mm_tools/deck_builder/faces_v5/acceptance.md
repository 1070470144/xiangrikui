# 卡组实体卡牌 v5 验收

对标参考已通过浏览器查看官方内容：
- 炉石传说：https://hearthstone.blizzard.com/en-us/cards — 内置费用徽章、名称横带、插画窗、正面纸张说明区域。
- 昆特牌：https://www.playgwent.com/en/media#/screenshots — 插画主体与细边界的层级。

使用 sprite-gen + 用户指定 gateway + gpt-image-2 生成原创植物卡面与卡背。普通：旧黄铜；稀有：银蓝宝石；传说：金色向日葵。没有复制参考游戏素材。

生成记录：本目录 prompt / report / raw 文件。第一轮要求原生透明但前面三张返回 RGB，拒绝发布；第二轮显式 chroma。卡背 raw 已是有效 RGBA，重复 chroma 导致主体消失，视觉验收后丢弃该抠色结果并保留原生 alpha，back.report.json 已记 accepted_alpha。前三张由 sprite-gen 抠色，均有透明外沿和不透明内部。运行时裁去透明边距并缩放至 700x860；完整纹理绘制，不采用九宫格。工具 workflow finish 的 provider 枚举只接受 codex/grok，不支持实际 openai 路线，因此未伪报渠道或保存默认设置。

前面：名称、消耗、品质、阶段、目标、效果、编入数量与解锁价格。背面：独立皮革植物纹章图，无描述文字。插画采用内框裁切；所有插画控件启用裁切。鼠标横向拖动旋转、点击翻面，正背面按角度切换。

验证：Godot headless 测试通过；图形模式原生鼠标点击、旋转、翻面、卡库拖入卡组、卡组拖回卡库测试通过。增加插画边界、正面描述、独立卡背及透明/不透明像素断言。素材 manifest validate / verify 通过。Godot 本机证书警告与该界面无关。

实机截图：
- res://art_source/evidence/deck_builder_runtime.png
- res://art_source/evidence/deck_card_front_v5.png
- res://art_source/evidence/deck_card_back_v5.png
- res://art_source/evidence/deck_card_rare_v5.png
- res://art_source/evidence/deck_card_legendary_v5.png
