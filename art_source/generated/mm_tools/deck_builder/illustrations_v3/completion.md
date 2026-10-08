# 24 张独立卡牌插画完成

原8张保持不变，使用 sprite-gen / gpt-image-2 / 已授权 gateway 为剩余16张逐张生成独立3:2插画。普通4张、稀有8张、传说4张。prompt / report / raw 保存在本目录。花园复生第一次请求超时无输出，单独补生成成功。美术保持深绿、深蓝阴影与暖金植物光，按卡牌效果确定独立主体，不采用图标复用或拼图切片。

运行时图片统一768x512，绑定文件名即卡牌id。卡库与点击详情共用 art_path，框位沿用三种品质已测量坐标。24/24图片存在且路径唯一。增加全卡牌独立插画覆盖检查；Godot headless与图形模式测试通过，包含点击、翻面、旋转和双向拖拽。素材清单validate/verify通过。

总览：res://art_source/evidence/remaining_card_art.png
卡库实机：res://art_source/evidence/deck_remaining_cards_runtime.png
阴影归化详情：res://art_source/evidence/deck_shadow_redemption_runtime.png

用户已指定付费API路线，sprite-gen guided workflow 不提供openai，按明确provider执行；未改默认设置。
