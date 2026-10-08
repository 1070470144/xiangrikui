# 强化页第二版

2026-10-02，使用用户指定接口及 gpt-image-2，通过安装版 sprite-gen 和项目 gateway 生成一张完整强化卡面。提示词与原始报告位于 `art_source/generated/mother_buff_v2/`；原始 PNG 留作证据，不参与 Godot 导入。密钥只从进程环境传入。

运行时底图 `assets/ui/generated/mother_buff_ui/mother_buff_card_v2.png` 包含铜叶边框、深绿标本展示区、淡色植物刻纹、标题铭牌、浅色纸质效果区与底部操作条。母花、标题、阶数、效果与操作反馈由 Godot 单独渲染。生成卡面接入 `mother_upgrade_choice_card.gd` 的按钮样式，替代旧的双重边框。

卡片高度从 350 增至 430，母花展示区从 95 增至 190；文字效果纸改为透明容器，使用底图上的纸材。母花强化选择弹层扩高，增加“三选一、立即生效、新形态”说明。悬停/键盘聚焦提亮卡面，按下时压暗，悬停提亮母花并显示确认提示。原有一键选择及形态绑定沿用。

验证：1152×648、1280×720、1920×1080 的实际 Godot 截图、效果文字布局、卡片边界及真实鼠标点击均通过；67 项母花/植物图片绑定检查通过。截图沿用 `output/imagegen/previews/mother-buff-paths-*` 和 `mother-buff-effects-*`。
