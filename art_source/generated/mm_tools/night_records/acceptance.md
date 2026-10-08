# 七夜记录美术与交互验收

参考：Hades 官方截图 https://www.supergiantgames.com/games/hades/ 的场景色彩与清晰信息层级；昆特牌官方 https://www.playgwent.com/en/media#/screenshots 的金属包边与材质界面。此处采用原创植物手绘场景和旧铜/皮革档案，未复制游戏素材。

sprite-gen / gpt-image-2 / 用户指定网关生成七张夜景、背景与档案底板，共9张独立素材。prompt、raw、report保存在本目录。前景文字由Godot绘制。夜晚主题按game.gd现有规则：平静、多向来袭、酸雨、雷雨、首领浓雾、补给、日蚀。面板中心低对比皮革，两端角部刻纹；缩略图与详情图片裁切在固定窗口内。

七个章节点击切换详情、选中状态与状态标签。页面默认选择下一夜，通关7夜时选择第7夜。显示真实本地账号进度与时间；没有虚构击杀或历史战绩。未完成章节可预览，页面没有添加开始战斗入口。返回与Escape沿用主菜单导航。

验证：七章图片绑定、0/3/7进度状态、章节选择、返回、图片窗口尺寸与章节边界通过；主菜单测试和菜单布局通过；素材manifest validate/verify通过。发现现有monster_animation_library.gd路径类型推断导致主菜单依赖编译失败，补显式String类型后通过。实机截图 res://art_source/evidence/night_records_runtime.png；全部插画 res://art_source/evidence/night_records_art.png。

明确使用用户已授权openai渠道。sprite-gen workflow枚举不支持此显式API路线，不伪报provider，不保存默认设置。
