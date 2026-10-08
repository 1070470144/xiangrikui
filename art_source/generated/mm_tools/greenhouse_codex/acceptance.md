# 温室图鉴验收

沿用本会话已查看的 Hades 官方截图 https://www.supergiantgames.com/games/hades/ 的手绘主体与信息层级，以及昆特牌官方 https://www.playgwent.com/en/media#/screenshots 的金属材质界面。使用 sprite-gen / gpt-image-2 / 已授权 gateway 生成4张原创展示插画、1张皮革档案底板和1张背景。prompt/raw/report均保留。没有复制游戏素材。

现有图鉴4个条目：荆棘花、棱镜花、影兽、蚀芽虫。改为分类按钮、左侧条目目录、中央独立大图、右侧资料。保留游戏内造型小图对照；植物生命/种子/范围/伤害/间隔和怪物生命/速度/伤害/间隔/首次夜晚读取 content_data 实际数据。未新增未完成的图鉴条目或虚构解锁记录。

图片缩放模式在加载前设置，防止原始尺寸覆盖文本。图文分区、分类/条目切换、返回和图片绑定通过headless与图形模式测试；主菜单测试及布局测试通过。manifest validate/verify通过。证据：res://art_source/evidence/greenhouse_codex_runtime.png 与 greenhouse_codex_monsters_runtime.png。

用户明确使用openai网关；sprite-gen guided workflow不支持openai枚举，按显式provider执行，不伪报渠道，不保存默认设置。
