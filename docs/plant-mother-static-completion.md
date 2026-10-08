# 植物槽、强化界面与母花形态交付

2026-10-02。按用户指定的 https://newapi.oairegbox.cc/ 和 gpt-image-2，使用安装版 sprite-gen 的 openai provider，经项目已有 gateway 适配器生成并校验静态图片。密钥只通过进程环境传入，没有保存在项目中。

## 游戏表现

- 默认五个植物槽，十五种可携带植物；光脉芽和修复不占槽。沿用已完成的种子消耗、昼夜限制与十种新增植物战斗能力。
- 补齐旧后三种与新增十种的十三张独立植物图片。部署卡、拖拽预览、植物槽、战场和温室图鉴使用同一物种图片。断光时保留物种形态并降低亮度。
- 温室图鉴扩为十五种植物，可滚动浏览；辅助植物没有伤害字段时正常显示基础资料。
- 母花有三张方向图和五十四张强化图。选择后立即换为该选项的形态，配合 0.65 秒绽放缩放；各分支各阶形态均不同。以最后一次选择决定当前形态，已获得的战斗效果仍累积。
- 强化卡片显示同一形态预览、分支阶数、准确数值效果与单次点击反馈；sprite-gen 生成铜叶透明卡框，文字保留原生渲染。
- 母花低生命保留当前进化形态，通过暗淡色调及原危险反馈表达受损；血条移至花冠上方。

## 素材与证据

运行时清单：`art_source/manifests/plant_mother_static_runtime.json`，含七十张植物/母花图片的尺寸、边界与 SHA256，以及强化卡框路径。植物画布 160×160，母花画布 256×256，根部对齐既有战场尺度。

`art_source/generated/plant_mother_static/` 保存提示词、sprite-gen 原报告、原始图片与未缩放 source 图片。此目录使用 `.gdignore`，源证据不参与游戏导入。`runtime_sizes.json` 记录缩放后的结果；原生成报告中的尺寸描述源图片。

首次批量的 summary 记录两个失败项；石盾花两次接口数据异常、聚光花心一次缺少真实 alpha，分别补齐后均已发布有效图片。最终以运行时清单和实际文件为准。没有自动付费重试，也没有视频生成；本次动画为游戏内缩放反馈。

实际 Godot 截图位于 `output/imagegen/previews/`：`mother-buff-paths-*`、`mother-buff-effects-*`（1152×648、1280×720、1920×1080），`plant-expansion-slots-stage12-1280x720.png`、`plant-expansion-catalogue-stage12-1280x720.png`、`mother-evolved-battle-1280x720.png`。

## 验证

- `test_plant_slots_expansion.gd`：46 项通过。
- `test_day_night_flow_independent.gd`：117 项通过。
- `test_mother_form_integration.gd`：67 项通过，覆盖全部五十四个强化与十三种植物的实际图片绑定、拒绝重复强化、重置与断光。
- `test_greenhouse_codex.gd`：十五种植物和两种既有怪物图鉴浏览通过。
- `mother_buff_ui_capture.gd`：三种分辨率的文字、卡片边界及真实鼠标点击通过。
- `mother_forms_capture.gd`：游戏接口连续六次强化及战场截图通过。

完整旧 `test_runner.gd` 仍报告已有 HUD 接口/布局、旧母花卡皮肤断言、九宫格与相机契约失败；这些失败在本次素材接入前已出现。与花目录有关的旧“六种植物”断言已更新为十五种槽植物加光脉芽。Windows CA 根证书与缺少 .NET SDK 的主机提示不影响本项目 GDScript 的上述检查。
