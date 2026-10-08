# 最后的向日葵：Godot 原型

这是依据 `Design/Sunflower-Defense-GDD.md` 与美术规范制作的 Godot 4.7.2 游戏原型。

## 运行

1. 启动 Godot 4.7.2。
2. 导入本目录中的 `project.godot`。
3. 按 `F6` / `F5` 或点击“运行项目”。

也可以直接运行：

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe' --path 'D:\MyData\GodotData\MyGame'
```

## 操作

- `1`：选择荆棘花，在有效供光土地上自由种植；
- `2`：选择棱镜花，在有效供光土地上自由种植；
- `3`：选择光脉芽，在现有供光范围内自由种植；白天消耗 15 光能，夜间紧急种植消耗 23；
- `Enter`：提前结束白昼，开始下一波；
- `Space`：选择太阳爆闪，点击战场确认施放；
- 鼠标右键或 `Esc`：取消当前选择；
- 白昼点击受损光脉节点：消耗 20 光能进行修复；
- `R`：胜利或失败后重新开始。
- `WASD` / 方向键 / 屏幕边缘：移动镜头；鼠标中键拖动；滚轮缩放；`F` 返回母花。

## 规则

- 五种可种植花朵分别承担范围输出、远程优先攻击、储光保护、减速和修复职责；
- 十种敌人按七夜逐步登场，包含突进、腐蚀、压制、支援、分裂、正面护甲和两个 Boss；
- 战场扩大为正方形世界，敌人可从八个方向进攻；
- 光脉芽由玩家自由种植并自动连接最近的有效光源；
- 光脉断裂后植物先消耗储光，再进入低光和休眠状态；附近有备用节点时会自动重连；
- 击杀敌人获得光能，太阳爆闪消耗 40 光能；
- 固定关卡包含七个夜晚：单向教学、八向围攻、酸雨、雷雨、首领、补给、最终首领；守住第七夜即胜利。
- 第一个白天从三种母花方向中选择一种，之后六个白天各从该方向的三个分支中选择一次强化；
- 玩家使用局外构筑的 12 张战斗卡组，初始抽 4 张，每张卡整局只能使用一次；
- 第二个白天起可以安全撤退并带回全部可提取种子，战败只带回 10%；局外种子用于解锁战斗卡和五级母花基础成长；
- 当前版本只有七夜战役，不包含无限模式。

## 自动验证

```powershell
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/test_runner.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/integration_smoke.gd
& 'D:\SoftWare\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . -s tests/content_system_smoke.gd
```

测试覆盖七夜流程、两层卡牌、十种敌人、五种可种植花朵、54项母花进化、24张战斗卡、撤退与失败结算、局外成长、账号持久化和主场景启动。

## 美术替换

原型已接入“末日温室厚涂绘本风”正式贴图，并保留程序绘制作为资源缺失时的降级方案：

- `assets/backgrounds`：战场背景与前景雾；
- `assets/core`：太阳母花健康、受损、濒危状态；
- `assets/plants`：荆棘花和棱镜花的供能、断能状态；
- `assets/enemies`：影兽和蚀芽虫的移动、攻击状态；
- `assets/nodes`：光核健康、受损、断裂状态；
- `assets/effects`：光弹、太阳爆闪、阴影消散；
- `assets/ui`：顶部面板、行动栏、按钮和技能图标。

贴图路径统一维护在 `scripts/art_library.gd`。替换同名 PNG 后重新导入项目即可更新画面，不需要修改战斗脚本。原始生成图、提示词与切图脚本保存在 `art_source/`，便于继续迭代同一美术风格。
