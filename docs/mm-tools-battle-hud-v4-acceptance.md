# 战斗 HUD V4 四阶段验收

2026-09-30；master；未提交或推送；只细化战斗 HUD 美术，保留 V3 稳定布局、主按钮、仪表、全部已有文件和游戏行为。

## 阶段 1 / 2：通过

定位、原风格采样、V3 baseline、临时实运行图、3母版批次和测试详见 `docs/mm-tools-battle-hud-v4-stage12.md`。V4 不是新增布局，沿用 V3 的生命/阶段/资源、行动托盘和主动作稳定锚点。真实提升：卡牌由文字框变成上半植物标本、下半名字/费用；修复独立类别图；顶部采用统一手绘玻璃和细双黄铜沿，操作带减视觉重量。Manifest `art_source/manifests/battle_hud_v4.json` schema 1 validate/plan 通过，展开3项；用户确认后进入生成阶段。

## 阶段 3：通过

只执行用户确认的3次 sprite-gen `mm-api / gpt-image-2`：status_frame、specimen_card_frame、action_tray_frame。源图/raw/无密钥报告在 `art_source/generated/mm_tools/battle_hud_v4/`；`mm_manifest.py verify` 通过。3件都有相同墨绿玻璃、窄黄铜双沿、上左暖柔光、稀疏角叶，无文字或额外图标、霓虹、环境、替代图。实际 native alpha 外围有效。

`art_source/process_battle_hud_v4.py` 读取同一 manifest 的输出与runtime需求，从不改变raw。status raw2083×755、实际bbox `[63,172,2021,575]`；card raw1254×1254、bbox `[124,93,1130,1153]`；tray raw1983×793、bbox `[80,261,1903,520]`。原图艺术内容宽高比与目标不同，角部均等比缩放，仅安静中心/直边扩展，避免整图压扁。输出status304×88、card142×110、tray620×126；Godot边界margins为实际纹理pixels，不使用原大图margin。

card原图标本窗约70%，caption约30%；直接全图缩放曾把金色分隔梁放在标题行，拒收后从source窗口/底签切分，窗口派生54px、余下caption48px，标题/费用全在安静底签。header/card亮度0.68、tray0.62，并轻减饱和，保留手绘材质和上左光而不过亮抢母花。派生值写入manifest runtime，报告在同目录derivation_report.json，`--check`可逐像素复现。

卡框四态从单normal母版派生，alpha SHA256均 `17be2457ad24682d7a8a86c56b70060415a447632ab36eccbf77ad646a4f88b8`。选中通过原生2px暖铜金outline，保留卡面亮度；disabled图去饱和并暗化，既有项目标本插画也降亮。动态卡片从同manifest组件binding载入四态，三顶部框/行动托盘通过 `ArtManifest` 明确节点绑定；没有生成器反向决定节点。

## 阶段 4：通过

最终3分辨率实运行图：`output/imagegen/previews/battle-hud-v4-<size>-hud-day-runtime.png`、`...hud-night-runtime.png`、`...hud-mother-choice-runtime.png`，size为1152x648、1280x720、1920x1080。另有每尺寸 `...specimen-normal/hover/pressed/disabled.png` 与复用主按钮四态运行图。对照本记录引用的V3 `output/imagegen/previews/battle-hud-v3-1280x720-hud-day-runtime.png` / `...hud-night-runtime.png`，可见原平色框和文字牌已换成成套绘本玻璃/铜框与标本卡。

符合项：中央与母花主体保持开放；母花仍是最亮焦点；文字动态读数与交互由Godot；卡图不压标题，金横梁在标题上方，名称和费用分行；窗口/底签边框连续无畸变；三顶部材质一致且阶段读数突出；行动带边饰安静，不添加大型装饰；选中太阳地雷具有清楚暖金outline；低能量爆闪保持禁用；V3主动作/仪表仍正确实际加载；母花强化三选一正常。

`tests/test_battle_hud_v3_runner.gd` 最终通过，覆盖三尺寸昼夜与5卡边界、底部18px、主动作快捷键/标题/费用间距、动作/卡牌信号、能量不足/恢复、母花选择、通知退出、标本图片存在/标题/费用不重叠、选中outline显示/撤销；断言V3主按钮四态与仪表路径保持加载，V4顶部3框/托盘的实际 `StyleBoxTexture` 路径、夜战动态卡的全部4态实际路径均通过。Manifest validate/verify 与派生--check通过。

修正记录：临时中文Label最小行高导致名字/费用区域重叠，名称调整14px和独立间距后重验；修复与部署图形相似改现有修复图；第一生成接入金横梁压标题及浅窗太亮，返回阶段3做窗口/底签分段与亮度修正，再重新执行全部3尺寸截图、绑定和行为检查；选中态单纯pressed暗化不明显，新增原生暖金细outline并重新拍摄/验证。

无本次任务范围内未处理差异。原V3已记录的7项旧v2全量suite未实现契约没有在此次宣称通过；目标行为检查通过。Godot实际GDScript运行只有机器既有证书存储提示，无资源缺失；Mono编辑器.NET SDK缺失不影响本次GDScript运行验收。没有再次模型调用。
