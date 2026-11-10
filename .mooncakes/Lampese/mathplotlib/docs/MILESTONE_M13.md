# M13：三角网格着色与原始面信息

创建日期：2026-10-25。状态：**已实现并通过 UI/外部接入专项；独立复审与中央完整验收已过，0.14.0实际交付已完成**。
目标0.14.0；当前实际分发0.13.0，正式基线为
`87a3280f31fb3ba043da415f89eab6ad5a8ef59e`。

本轮补已有 `tripcolor` 和 `tripcolor_triangulation` 的交互，支持逐面标量
及原有顶点算术均值。保持既有绘制和参数，不增加场插值或重建三角网格。

## 能力合同

- [x] 新增 `HitKind::Tripcolor`，复用实际 Polygon 成功写出的单环 nonzero
  `FilledRegion`；两种命中模式均要求 plot 内真实填色，掩码空面、三角形 bbox
  空角、退化面与 margin 不产生误命中。
- [x] `value` 保原有限逐面值或原有 `(a+b+c)/3` 的运算结果；保留原均值位模式、
  溢出省略、全输入 normalization autoscale 和 face 数量优先规则。
- [x] `point_index` 为实际验证或生成网格的原面槽，保留 mask/无效值的空位；
  `artist_index` 为当前实际 Polygon，`series` 为生成调用的名称。
- [x] `TriColorInfo` 提供实际有序顶点三元组和 `vertex_mean` 标志；通过可选
  `HitInfo.tricolor`、factory 和根 facade 提供。自动 Delaunay 结果也保留实际顶点索引，
  不以矩阵行列、颜色或重新计算的网格代替来源。
- [x] 默认提示显示系列与 Value 或 Vertex mean，自定义提示可读取原面和顶点信息；
  生成边的几何锚点不作为原始观测或鼠标处标量场值展示。
- [x] 三点身份与内容快照、known-slot 与线性 cursor 维护归属；不匹配或未知 prepared
  context 保守静态，保留 image/inline/remove/clear 和其他图类的既有行为。
- [x] 保持原签名、Unit 返回、0 Containers、mask/triangulation、normalization、
  图例、颜色及同目标旧 SVG。若实际复现空调用串改前一 series，只窄修该问题。
- [x] 每面保持常数大小元数据和三点检查，不对每面复制或扫描整个网格；
  preparation/capture 为 O(artists + faces)，每个相关面的包含查询为 O(3)。

## 验收与交付

- [x] 显式三角面、triangulation wrapper、自动 Delaunay、逐面/逐顶点输入及等数量优先规则。
- [x] 原面槽洞、同均值不同面、mask、无效值、旧均值舍入/溢出与 normalization-only 重绘。
- [x] 实际非零三角区域、bbox 空角、重叠后绘制优先、孔洞透选、反轴/Log、plot/margin
  边界与完整覆盖 plot 的几何锚点。
- [x] 原数组与 getter 别名、跨调用/跨 kind/未知 prepared、image/inline/remove/clear、旧 Drawing。
- [x] 同目标旧 SVG、独立 Native/JS 实际 XML 与命中 oracle、必要四目标和 adapter。
- [x] 真实双卡 DOM、默认和中文均值提示、更新/掩码/图例/重挂载/CSS/375px。
  浏览器以实际 Polygon 的 `isPointInFill` 和真实 plot bounds 为独立依据。
- [x] 中央真实 info/fmt/结构、一次完整回归、既有浏览器示例与静态示例。
- [x] clean 包、实际 Mooncakes、全新无 workspace 安装、GitHub 四附件完整下载与固定源码审计。

只读准备先用精确旧0.12源运行3个 Native/XML 基线：掩码原面槽0/2/3对应值10/30/40，
顶点均值5/7/9/7；facecount等于vertexcount时仍按逐面值2/5/11/17处理。
这些旧图均没有语义 targets，返回Unit且没有Container。有关tripcolor的完整源码块与
0.13正式源逐字相同。随后已实际冻结精确87a的Native/JS各3份旧SVG/XML，
新交互与同目标旧输出分别核对，不把旧基线重标为新验收。

## 已执行的专项

- 首核心 `9702f5c` 的三个固定场景、自动 Delaunay、原均值舍入/溢出、全输入 norm、
  mask 与重叠、反轴/Log、clip/wholeplot/margin、生命周期及跨 kind guards 通过
  独立 Native/JS 有界核对。1120 个额外实际 XML 物理查询一致，
  两个既有 ContourF 控制的 SVG、region、anchors 保持不变。
- 实际 Chrome 双卡首轮 **14/14**、0 页面错误，29 个整数鼠标事件与请求相符；
  覆盖默认/中文提示、mask 真实前后、norm-only repaint、数据更新、legend、重挂载和375px。
  七个示例文件已提交 `81fc697`。
- 外部公开 consumer Native/JS 构建及 Chrome **46/46**、0 页面错误；
  11 个实际三角面事件核对 raw values15/35/45、均值8/10/12/10、原面槽与有序 tuple。
  实际 info/fmt 通过，private interfaces 不变；提交 `19ce678`。
- 已保留并修复两个实际数值反例：原共线三点被独立 screen rounding 打开，
  以及统一归一化 scale 导致异量纲合法面丢失。最终窄修 `a7f53f2`
  在两个阶段均按 X/Y 独立纯2幂缩放；不改 SVG writer 或填色容差。
  owner Native9/JS8定向通过；独立最终Native43311/JS94555七组delta均通过，
  14份同目标SVG不变，exact Fraction证明3共线/4合法，无剩余blocker。
- ENOSPC 只中断环境写盘/最后info与review setup，失败日志保留；
  已清理旧可再生成缓存，继续受影响步骤，没有重跑已通过的完整历史矩阵。

producer在独立工作树负责core/own tests和[专项指南](TRIPCOLOR_INTERACTION.md)，
Root负责版本、中央文档、consumer、UI与真实交付。最终owner36files（19production/3interfaces/13tests/guide）已与Root逐SHA一致，
a7专项Native23/其余22、adapter2通过；旧bac7 broader205/204/48只作为未改部分依据。
唯一中央全套81669已通过（267.69s）：Wasm/Wasm-GC各22611、Native22614、JS22666。
prelude94492和postlude29009全部0，14页面Chrome176项/0errors、info/fmt/14JS、
三个静态SVG、50份文档562个本地链接、结构与diff均通过，无意外接口变化。
最终三角面截图与冻结asset逐字相同。0.14.0实际发布与独立安装闭环已完成。

[执行检查点](MIGRATION_STATUS.md) · [当前能力](CAPABILITIES.md) · [路线图](MIGRATION_PLAN.md)

## 正式交付

正式源 `1215721c9e63e7036be9580ecd1560e7eabe0be3`，
[GitHub v0.14.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.14.0)。
实际publish200，首公开API构建成功/包可用/未撤回/checksum一致；无workspace全新registry
安装600份文件逐一等于正式ZIP，四目标静态和Chrome46通过。四附件完整下载后
bytes/digest/size/tag全部一致；正式builder至最终audit没有Root tracked写或commit。

- Module ZIP：2576088bytes，SHA256 `ad6d8b29519c75f25039e961daa2f9a74127bfc05b510fe1ba11a3d457f8c51f`。
- Source ZIP：2627432bytes/627files，SHA256 `a4700d81c5f3d26fa0912e9dcd9b80090e88a24d6eb62df90435a56dbc60ff76`。

以上发布结果在网络闭环完成后记录；正式包内保留发布前的候选验收记录。
