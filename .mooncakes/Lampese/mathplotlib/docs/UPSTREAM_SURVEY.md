# Matplotlib 上游能力盘点

本盘点固定了本项目的第一份上游参考，避免“全能力”变成没有边界的口号。

## 上游基线

- 项目：`matplotlib/matplotlib`
- 版本：`v3.11.2`
- 提交：`d3ca9172e392048ec242b90e8423e88d1a3000b2`
- 来源：<https://github.com/matplotlib/matplotlib/tree/v3.11.2>
- 许可证：Matplotlib 项目许可证；迁移代码和数据文件必须逐项保留许可证与归属信息。

本地调查使用了该 tag 的源码和 `.pyi` 公共签名。源码目录约有 76 个顶层 Python 模块和 59 个顶层类型存根，另外包含 `axes`、`backends`、`projections`、`tri`、`mpl_toolkits` 等子系统。这个规模决定了迁移必须按层推进，不能按文件逐个机械翻译。

## 能力分层

### A. 纯 MoonBit 核心

这些模块优先做到 Wasm、WasmGC、JS 和 native 目标的一致语义：

- 基础类型、数组输入和数据清洗。
- `transforms`、`path`、`bezier`、`bbox` 等几何变换。
- `colors`、`cm`、`Normalize` 和颜色映射。
- `scale`、`ticker`、`dates`、`category` 等坐标和刻度系统。
- `artist`、`lines`、`patches`、`collections`、`text`、`image`、`table` 等场景图元。
- `figure`、`axes`、`axis`、`gridspec`、`layout_engine`、`legend`、`colorbar`。
- `pyplot` 的对象式等价调用和状态管理。

### B. 可移植输出后端

先完成 SVG，再按相同场景接口实现：

- SVG：文本、路径、裁剪、透明度、渐变、图像嵌入。
- Canvas/HTML：在 JS 或 Wasm 宿主中提供。
- JSON/场景导出：用于测试、调试和其他前端。

这些后端不应重新实现坐标轴和图元逻辑。

### C. native 后端和原生依赖

这些能力需要单独的 native 包和 C/C++ FFI，不能污染纯 MoonBit 核心：

- Agg 栅格化。
- PNG、JPEG、TIFF 等图像读写。
- PDF、PS、PGF 和 Cairo 输出。
- FreeType 字体加载和高级文本测量。
- Qhull、三角剖分和部分等值线算法。

对应的 FFI 包必须有独立的许可证清单、最小 C stub、native 链接配置和 ASan 测试。

### D. 宿主交互和生态能力

这些能力仍然属于完整迁移目标，但按宿主单独交付：

- Qt、GTK、Tk、macOS、WX 等 GUI 后端。
- WebAgg、Notebook、WebSocket 和事件循环。
- `animation`、`widgets`、鼠标/键盘事件和工具栏。
- `mpl_toolkits`、`mplot3d`、`axisartist`、`axes_grid1`。
- 与 pandas、xarray、Pillow 等生态对象的适配层。

在没有对应 MoonBit 宿主接口时，先提供可测试的协议和数据模型，再实现具体适配器。

## 上游依赖与 MoonBit 对应策略

| 上游依赖 | 主要用途 | MoonBit 策略 |
| --- | --- | --- |
| NumPy | 数组、广播、数值计算 | 先定义 `ArrayLike` 对应的核心数组 API；必要算法使用 MoonBit 原生实现 |
| ContourPy | 等值线 | 纯 MoonBit 算法包，或 native 适配包；不把 Python 依赖带入核心 |
| FreeType/fontTools | 字体和字形 | `native/text` FFI；SVG 首期使用明确的字体回退策略 |
| Pillow | 图像编解码 | `native/image` 或宿主适配器 |
| kiwisolver | 约束布局 | `internal/layout` 先定义稳定接口，再决定纯 MoonBit 求解器或 FFI |
| pyparsing | 数学文本和格式解析 | `internal/parser` 纯 MoonBit 解析器 |
| python-dateutil | 日期轴 | `core/datetime` 和 `ticker/date` |
| cycler/packaging | 样式循环和版本/配置 | `style`、`config` 内部模块 |

## 目标包图

目标包按依赖方向排列，箭头表示“可以依赖”：

```text
core/types ──┐
core/numeric ├──> transforms ──> scene/artist ──> scene/axes ──> pyplot
core/colors ─┘          │              │              │
                        └──────────────┴──────> backend/svg
                                             ├──> backend/canvas
                                             └──> backend/native/*
```

建议的公共包所有权如下：

- `core`：数据、颜色、数值和错误类型。
- `transforms`：坐标变换、边界框和路径几何。
- `scene`：Figure、Axes、Artist 及布局结果。
- `ticker`：Locator、Formatter 和日期/分类刻度。
- `backend/*`：后端编码和宿主接口。
- `pyplot`：面向用户的便利门面，只组装 `scene`。
- `internal/*`：解析、文本测量、算法辅助和验证。

## 迁移顺序

1. **源签名和语义清单**：从 `.pyi`、公开文档和测试提取公共类型、方法、默认值和异常行为。
2. **核心数据和数值**：数组输入、颜色、范围、变换、路径和确定性浮点规则。
3. **场景对象**：Artist 树、Axes、Figure、GridSpec、Legend 和 Colorbar。
4. **SVG 后端**：先完成可复现的静态输出和结构测试。
5. **基础图表 API**：`plot`、`scatter`、`bar`、`fill_between`、`errorbar`、`hist`、`imshow`、`contour`、`quiver`、`streamplot` 等逐项加入。
6. **刻度、文本和布局**：线性/对数/日期/分类刻度，数学文本，图例和自动布局。
7. **高级算法**：三角剖分、3D、颜色条、动画和统计辅助。
8. **native 和宿主后端**：Agg、PDF、PNG、GUI、Web 和 Notebook。
9. **生态适配与兼容回归**：Pillow、pandas、xarray 等适配器及完整回归夹具。

## “全能力”的验收定义

完整迁移不要求 MoonBit 复用 Python 的内部实现，而要求：

- v3.11.2 的公开模块和公开对象都有对应的 MoonBit API 或明确的宿主适配包。
- 默认值、数据形状、坐标语义、图元顺序和错误行为有可执行测试。
- 至少 SVG 后端在 Wasm/native 上可用；native/GUI 能力按平台矩阵单独标记。
- 每个后端都消费同一个场景模型，不能复制上层绘图逻辑。
- 上游测试按功能切片迁移，不能只用“字符串包含 `<svg>`”作为最终正确性证明。
- 未支持的能力必须出现在兼容性清单中，不能静默降级成错误图形。

## 当前实施点

当前仓库已经完成从 `core` 数据模型到 `scene` 图元和 SVG 后端的多条可验证切片，并保留根包门面。最新的 masked array 切片覆盖值/掩码模型、自动色阶排除、线段断点、填充区域、图像和规则网格的 bad 色语义；下一步继续深化布局、共享轴和后端协议，同时按各统计 API 的数据语义分别迁移掩码输入。
