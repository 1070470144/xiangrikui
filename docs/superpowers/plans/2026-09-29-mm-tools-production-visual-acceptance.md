# mm-tools Production Visual Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `mm-tools` reject any Godot UI with visible text, alignment, spacing, overlap, clipping, hierarchy, state, asset, or style defects until every required runtime screenshot passes production-quality acceptance.

**Architecture:** Keep the existing four-stage workflow and strengthen its contracts rather than adding a parallel process. A focused Python contract test will assert that the skill contains the required production gate, screenshot matrix, evidence requirements, and deterministic rework routing; the skill document will define the human-review criteria that cannot be reduced to geometry tests. A validation record will capture the failing baseline and final verification without changing the Manifest schema, generator, provider, or Godot binding code.

**Tech Stack:** Markdown skill instructions, Python 3 `unittest`, Codex skill `quick_validate.py`, Godot runtime screenshot evidence conventions.

---

## File Structure

- Modify `aiskill/mm-tools/SKILL.md`: extend stages 1–4 with a visual contract, production acceptance matrix, blocking defects, evidence rules, and rework routing.
- Create `tests/test_mm_tools_skill.py`: enforce the non-negotiable structure and wording of the production visual gate.
- Create `docs/superpowers/validation/2026-09-29-mm-tools-production-visual-acceptance.md`: record baseline failure, implementation coverage, and final command results.
- Preserve all existing unrelated working-tree changes. Do not modify `mm_manifest.py`, the manifest schema, generators, Godot scenes, scripts, or generated art for this task.

### Task 1: Add executable skill-contract tests

**Files:**
- Create: `tests/test_mm_tools_skill.py`
- Test: `tests/test_mm_tools_skill.py`

- [ ] **Step 1: Create the failing contract test**

Create `tests/test_mm_tools_skill.py` with the complete content below:

```python
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SKILL_PATH = ROOT / "aiskill" / "mm-tools" / "SKILL.md"


class MmToolsSkillContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.skill = SKILL_PATH.read_text(encoding="utf-8")

    def test_defines_production_visual_contract_before_implementation(self) -> None:
        required = (
            "上线视觉契约",
            "对齐网格",
            "文字规则",
            "组件间距",
            "安全区域",
            "关键状态矩阵",
        )
        for phrase in required:
            self.assertIn(phrase, self.skill)

    def test_requires_runtime_screenshot_matrix(self) -> None:
        required = (
            "1152×648",
            "1280×720",
            "1920×1080",
            "2560×1440",
            "16:10",
            "Godot 实机截图矩阵",
        )
        for phrase in required:
            self.assertIn(phrase, self.skill)

    def test_lists_blocking_visual_defects(self) -> None:
        required = (
            "文字截断",
            "错误换行",
            "基线不齐",
            "间距不一致",
            "控件重叠",
            "内容裁切",
            "异常拉伸",
            "风格漂移",
        )
        for phrase in required:
            self.assertIn(phrase, self.skill)

    def test_forbids_soft_pass_and_requires_dual_review(self) -> None:
        required = (
            "自动化布局检查与人工视觉检查必须同时通过",
            "基本通过",
            "可接受",
            "后续优化",
            "零未处理差异",
        )
        for phrase in required:
            self.assertIn(phrase, self.skill)

    def test_routes_failures_to_responsible_stage(self) -> None:
        required = (
            "返回阶段 1",
            "返回阶段 2",
            "返回阶段 3",
            "重新执行其后的全部阶段",
            "复验所有受影响的分辨率与状态",
        )
        for phrase in required:
            self.assertIn(phrase, self.skill)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the new test and verify the baseline fails**

Run:

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_tools_skill -v
```

Expected: `FAIL`; the existing skill does not yet contain the complete production visual contract, screenshot matrix, blocking-defect vocabulary, dual review rule, and explicit revalidation language.

- [ ] **Step 3: Record the red-state evidence**

Create `docs/superpowers/validation/2026-09-29-mm-tools-production-visual-acceptance.md` with:

```markdown
# mm-tools 上线级视觉验收验证记录

## 范围

验证 `aiskill/mm-tools/SKILL.md` 是否能阻止带有文字、对齐、间距、重叠、裁切、层级、状态、资源或风格问题的 Godot UI 被判定完成。

## 基线

- 命令：`python -m unittest tests.test_mm_tools_skill -v`
- 预期：失败。
- 原因：现有技能虽要求最终截图和差异修正，但未完整定义上线视觉契约、固定分辨率矩阵、阻断缺陷清单、自动化与人工双重验收，以及明确的禁止软通过规则。

## 实施后验证

待执行完成后填写实际命令结果。
```

- [ ] **Step 4: Commit the contract test and baseline record**

Run:

```powershell
git add -- tests/test_mm_tools_skill.py docs/superpowers/validation/2026-09-29-mm-tools-production-visual-acceptance.md
git commit -m "test: define mm-tools production visual gate"
```

Expected: only the new contract test and validation record are committed; unrelated working-tree changes remain untouched.

### Task 2: Strengthen the four-stage skill workflow

**Files:**
- Modify: `aiskill/mm-tools/SKILL.md`
- Test: `tests/test_mm_tools_skill.py`

- [ ] **Step 1: Preserve existing work before editing**

Read the complete current `aiskill/mm-tools/SKILL.md` immediately before applying the patch. Treat its current content as authoritative and retain all existing branch, provider, secret-handling, non-overwrite, Manifest, Godot-runtime, and four-stage requirements. Do not replace the whole file; insert the following requirements into their matching sections.

- [ ] **Step 2: Add the stage 1 production visual contract**

Under stage 1, after the project-style analysis and before the stage output, insert:

```markdown
#### 上线视觉契约

布局确定前必须写明上线视觉契约，至少包含目标平台、验收分辨率、信息层级、主操作、对齐网格、文字规则、组件间距、安全区域和关键状态矩阵。关键状态按功能实际覆盖默认、悬停、按下、键盘焦点、禁用、选中、弹窗、长文本与内容密集状态；不适用的状态必须说明原因，不得直接遗漏。

同时从项目现有界面提取字体、颜色、圆角、描边、阴影、材质、图标尺度与视觉密度规则。没有完成上线视觉契约时，临时 UI 可运行也不能判定布局已经确定。
```

Extend the stage 1 output and gate so they explicitly require the approved visual contract.

- [ ] **Step 3: Add measurable layout requirements to stage 2**

Before the stage 2 output, insert:

```markdown
临时 UI 和正式布局必须把可客观判断的质量要求转化为检查项或自动化断言，至少覆盖控件边界、最小间距、文本容器、安全区域、锚点、容器行为、重叠、越界与裁切。自动化布局检查通过只代表几何基础合格，不能代替阶段 4 的人工视觉检查。
```

Extend the stage 2 gate so the layout checks must pass together with Manifest validation, functional tests, and runtime checks.

- [ ] **Step 4: Add runtime resource-display checks to stage 3**

Before the stage 3 output, insert:

```markdown
在实际显示尺寸下检查九宫格和纹理无异常拉伸，透明边缘无脏边、白边或污染，字体与图标清晰，各交互状态的资源构图和视觉重量一致，并且不存在 AI 错误文字、水印、比例失真或状态切换时的构图跳动。文件存在、绑定成功、单张资源校验通过都不能替代这些运行时检查。
```

Extend the stage 3 gate so failed display-quality checks keep the feature in stage 3.

- [ ] **Step 5: Replace the stage 4 acceptance body with the production gate**

Retain the existing comparison inputs, then append the following complete subsection:

```markdown
#### 上线质量硬门禁

阶段 4 必须依次完成四组验收，任一组失败即判定整个阶段失败：

1. **功能验收：**入口、返回、点击、滚动、键盘焦点、禁用状态、弹窗阻断、状态反馈和减少动态效果正确。
2. **几何验收：**控件无重叠、裁切、越界、遮挡、异常拉伸或尺寸跳变；网格、边距、文字基线和同类组件尺寸一致。
3. **视觉验收：**文字、信息层级、状态辨识、资源质量、风格一致性和整体观感达到可直接上线的标准。
4. **上线完整性验收：**所有目标分辨率和关键状态均有实机证据，自动化布局检查与人工视觉检查必须同时通过，并达到零未处理差异。

默认 Godot 实机截图矩阵覆盖 1152×648、1280×720、1920×1080、2560×1440 与至少一种 16:10 分辨率；目标平台、项目规范或用户要求更严格时采用更严格标准。每个分辨率覆盖该功能适用的默认、悬停、按下、键盘焦点、禁用、选中、弹窗、长文本和内容密集状态。截图文件名必须能够识别分辨率与状态。

每张截图逐项检查并记录：

- **文字：**无文字截断、溢出、错误换行、乱码、模糊或字重混乱；同级文字字号、颜色、文字基线与行高一致，文字不贴边或遮挡信息。
- **对齐与间距：**标题、正文、按钮、图标、数值和面板边缘遵循统一网格；无基线不齐、肉眼可见偏移或间距不一致。
- **布局与层级：**无控件重叠、内容裁切、越界、遮挡、异常拉伸或尺寸跳变；主操作五秒内可找到，当前焦点一秒内可识别，装饰不压过功能信息。
- **状态：**默认、悬停、按下、焦点、禁用与选中状态清晰，且危险、禁用、选中和焦点不只依赖颜色区分；视觉状态与真实交互一致。
- **资源与一致性：**无 AI 错误文字、水印、黑边、白边、脏边、透明污染、比例失真、构图跳动或风格漂移；颜色、字体、圆角、描边、阴影、材质、图标尺度与控件密度符合项目既有语言。

任何肉眼可见的不舒服、不整齐或错位都属于阻断问题，不能以“误差很小”“功能可用”或自动化测试已通过为由忽略。确需接受的差异必须具有明确设计依据并写入验收报告。

最终结论只能是“通过”或“未通过”。禁止用“基本通过”“可接受”“后续优化”等表述绕过门禁。
```

- [ ] **Step 6: Add deterministic evidence and rework routing**

Replace the existing stage 4 output and completion gate with:

```markdown
**阶段产物：**Godot 实机截图矩阵；逐图验收表；功能测试与自动化布局检查结果；每个问题的位置、所属阶段、修正内容和复验结果；零未处理差异的最终结论。网页截图、HTML mockup、离线合成图和单独资源预览不能作为完成证据。

**返工路由：**信息层级、布局结构或操作路径问题返回阶段 1；控件尺寸、锚点、容器、文本适配或布局代码问题返回阶段 2；图片尺寸、透明边缘、九宫格、资源状态或绑定问题返回阶段 3。修正后必须重新执行其后的全部阶段，并复验所有受影响的分辨率与状态。

**完成门禁：**功能正确、交互完整、全部目标分辨率与关键状态均无可见错位、文字问题、间距混乱、重叠、裁切、异常拉伸、层级不清、状态错配、资源瑕疵、风格漂移或其他未处理差异，并且整体观感达到可直接上线的舒服与整洁程度时，才可判定完成。缺少任何必要证据或存在任何阻断问题时，结论必须为“未通过”。
```

- [ ] **Step 7: Run the focused contract test**

Run:

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_tools_skill -v
```

Expected: `Ran 5 tests` and `OK`.

- [ ] **Step 8: Commit the skill change**

Run:

```powershell
git add -- aiskill/mm-tools/SKILL.md
git commit -m "feat: enforce production visual acceptance in mm-tools"
```

Expected: only `aiskill/mm-tools/SKILL.md` is committed; unrelated working-tree changes remain untouched.

### Task 3: Validate the skill package and close the evidence record

**Files:**
- Modify: `docs/superpowers/validation/2026-09-29-mm-tools-production-visual-acceptance.md`
- Test: `aiskill/mm-tools/SKILL.md`
- Test: `tests/test_mm_tools_skill.py`

- [ ] **Step 1: Run the complete focused unit-test module**

Run:

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_tools_skill -v
```

Expected: all five tests pass.

- [ ] **Step 2: Run the existing Manifest regression tests**

Run:

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' -m unittest tests.test_mm_manifest -v
```

Expected: the existing Manifest tests pass, proving that the documentation-only skill enhancement did not alter the manifest pipeline.

- [ ] **Step 3: Validate the skill package structure**

Run:

```powershell
& 'C:\Users\mengmenglv\AppData\Local\Programs\Python\Python311\python.exe' 'C:\Users\mengmenglv\.codex\skills\.system\skill-creator\scripts\quick_validate.py' 'D:\MyData\GodotData\MyGame\aiskill\mm-tools'
```

Expected: the validator reports the skill package is valid.

- [ ] **Step 4: Check the changed files for whitespace errors**

Run:

```powershell
git diff --check -- aiskill/mm-tools/SKILL.md tests/test_mm_tools_skill.py docs/superpowers/validation/2026-09-29-mm-tools-production-visual-acceptance.md
```

Expected: no output and exit code `0`.

- [ ] **Step 5: Replace the validation record's pending section**

Replace `待执行完成后填写实际命令结果。` with the actual results using this structure:

```markdown
### 技能契约测试

- 命令：`python -m unittest tests.test_mm_tools_skill -v`
- 结果：5 项通过。

### Manifest 回归测试

- 命令：`python -m unittest tests.test_mm_manifest -v`
- 结果：记录实际通过数量与状态。

### 技能结构验证

- 命令：`quick_validate.py aiskill/mm-tools`
- 结果：通过。

### 文本质量检查

- 命令：`git diff --check -- ...`
- 结果：通过，无空白错误。

## 结论

`mm-tools` 已将上线视觉契约、实机截图矩阵、阻断缺陷、自动化与人工双重验收、确定性返工路由和零未处理差异写为完成硬门禁。Manifest、生成接口和 Godot 绑定协议未改变。
```

Use the real Manifest test count from Step 2; do not copy an assumed number.

- [ ] **Step 6: Commit the completed evidence record**

Run:

```powershell
git add -- docs/superpowers/validation/2026-09-29-mm-tools-production-visual-acceptance.md
git commit -m "docs: verify mm-tools production visual gate"
```

Expected: the validation record contains the actual command outcomes and is the only file in this commit.

