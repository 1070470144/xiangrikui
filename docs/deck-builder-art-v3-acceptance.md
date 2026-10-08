# 卡组美术优化 · 2026-09-30

首屏八张卡使用独立生成的植物题材插画，替换原先重复的小图标。主题依次为日光长矛、缠绕根系、治愈露珠、防御根墙、太阳种荚、诱光花苞、植物灯笼和聚光花环。统一深绿、蓝绿阴影和暖金高光，费用、名称及交互文字由 Godot 在插画外绘制。

生成沿用用户授权的网关与 `gpt-image-2`，每张独立调用 sprite-gen `gen --provider openai`。生成入口为 `art_source/generate_deck_art_v3.py`，密钥仅通过进程环境变量读取。源图、原始图、提示词及报告保存在 `art_source/generated/mm_tools/deck_builder/illustrations_v3/`。运行时资源发布至 `assets/ui/generated/deck_builder/illustrations_v3/`，最大 768×512；清单记录源尺寸、运行资源和组件绑定。

卡面插画扩大至约 152×82，加入细黄铜书角并统一边框几何。费用与时段位于卡面上方，稀有度、编入数量或解锁价格位于下方。详情插画扩大至 104×64。其余卡牌继续使用原有主题图标，缺失新资源时可回退。

验证：卡组独立功能与布局测试通过；资源清单 validate 和 verify 通过；Godot 实际 OpenGL 捕获 `tmp/deck-builder-art-v3-final.png`。1152×648 下四列、两排完整显示，卡面宽 168–169、高 196，保存按钮 180×48。此次只运行与本轮卡组改动相关的测试。
