# Rabbita 可交互 DOM：G2.1 与 M2

状态：**首个切片已实现，并于 2026-10-24 通过真实浏览器验收。**
M2 v0.2.0 补齐资源隔离与独立源码版本包，历史验收见 [M2 记录](MILESTONE_M2.md)。
当前组件位于统一模块 `Lampese/mathplotlib@0.2.1` 的 `rabbita` 子包，安装与发布状态见 [接入说明](PUBLISHING.md)。
用户所说的 Rabbit-TEA 在上游项目中已更名为 [Rabbita](https://github.com/moonbit-community/rabbita)。
本片提供折线/散点的交互组件与双图应用；缩放、平移等后续能力仍属于 G2。

0.3.0 新增整柱/饼图区域、直方图区间与折线横轴吸附、自定义提示；当前契约见[提示指南](TOOLTIPS.md)。
以下保留 G2.1/M2 的实现说明与首次验收范围。

## 现在能运行什么

从仓库根目录运行：

```sh
moon build rabbita/cmd/demo --target js
python3 -m http.server 8765 --bind 127.0.0.1
```

打开 [本地示例](http://127.0.0.1:8765/rabbita/)。悬停查看数值、点击选中点、点击图例切换系列，
并可更新数据、移除和重新挂载两个图表。停止服务用 Ctrl+C。
[完整接入指南](../rabbita/README.md)包含包导入、消息与状态处理；
[示例源码](../rabbita/cmd/demo/main.mbt)展示 model/update/view 的完整组合。

![真实浏览器中的双图应用](../assets/rabbita-interactive.png)

截图是实际应用展示预览，不代表独立 PNG 导出。交互由下面的浏览器自动化另外验证。

## 接口与数据流

1. 用原有 Figure/Axes API 准备图表，调用 `Figure::to_drawing()`。
2. 现有 SVG 渲染在同次绘制中收集最终坐标下的数据点锚点，返回平台无关的 `Drawing`。
3. 同模块的 Rabbita 子包用 XML 事件读取快照，通过公开 `svg.node` / `svg.text` 构造有 namespace 的真实 SVG 节点。
4. `view(drawing, id~, on_event~, hovered?, selected?, legend~, hit_radius~)` 返回 Rabbita `Html`；
   hover/click/legend 消息交给应用更新状态，再准备视图。

核心新增 `drawing` 包与根包 `Drawing` / `HitPoint` 类型导出。
快照包含 SVG、宽高以及复制的数据点列表；旧快照不受后续图表或数组修改影响。
`to_drawing()` 传播现有 checked 数据/刻度/布局错误；原有 `to_svg_checked()` 可继续使用。

`HitPoint` 含 panel/artist/原始 point 索引、数值数据坐标和内在 SVG 坐标。
缺失值、超出 domain/视口的点被过滤时仍保留原始索引；阶梯线不使用展开后的顶点索引。
隐藏、None 线型或零线宽的折线不注册命中点，gapcolor 的额外绘制也不重复注册。

这些是**当前帧的数据点锚点**，不是像素轮廓、线段或跨重排的持久 ID。
点锚点覆盖 Line、Scatter、PathCollection；零半径散点仍可具有语义数据点。
应用在数据重排、更新或移除图表后应刷新或清空旧 hover/selection，示例已经这样处理。

### 复用选择与开销

本片复用现有 SVG 几何和布局，不维护另一套坐标算法，不重写 renderer。
XML 读取后调用公开节点构造器，没有 `innerHTML` 或 Rabbita 私有 VDOM 依赖。
未知标签、属性或不支持的视口配置会抛出 `AdapterError`，避免静默丢失输出。

每次 `view` 读取快照 SVG；最近点查询线性扫描锚点。大数据性能、缓存与空间索引留待实际需求驱动。
这是一条已验证的接入路径，还没有抽象通用 vector sink。

## 事件与布局契约

- HTML 视口容器监听 mousemove/mouseleave/click；图例按钮为其兄弟节点，不会顺带触发图内点击。
- 同步从事件 `currentTarget` 查询自身 SVG，读取实际 `getBoundingClientRect` 和 client 坐标。
  不用会随子节点变化的 offsetX/Y。
- 支持响应式 CSS 宽度、滚动、外层 padding/border；实际 SVG 的 `xMidYMid meet` letterbox 参与坐标换算。
  默认命中半径为 10 CSS 像素，尺寸变化后仍按 CSS 像素判断，空白 letterbox 区域不命中。
- 根 viewBox 必须为与 Drawing 尺寸一致的 `0 0 width height`，宽高为正；
  只接受默认或显式 `xMidYMid meet`。
- 每图使用不同的 `id`。图例 key 由应用定义；hover/selection 为应用状态。
  `create_pure_state` / `Val.view` 必须在 `rabbita.new` 的组件 builder 内创建。
- 直接加在 SVG 根上的 border/padding、任意 CSS transform、其他 preserveAspectRatio、触摸手势、
  缩放/平移和键盘导航均未覆盖。M2 已为各图 ID 和本地 url/href 引用加稳定作用域。
  SVG ARIA 属性仍不受公开 Rabbita API 支持，不能据内部 IDREF 转换宣称可渲染。
- XML 解码支持更多 SVG 图元，不等于其他所有图表都已具备交互。

## 依赖与平台边界

`rabbita/` 现在是统一模块中的 `Lampese/mathplotlib/rabbita` 包，建议显式别名 `@plot_dom`。
子包及 browser executable 通过 `supported_targets = "js"` 限定平台；
核心 facade、Scene、Drawing 与 SVG renderer 不 import UI，公开模型中没有 UI 类型。

统一模块安装会解析全部声明依赖，包含 Rabbita `0.16.7` 和 XML `0.5.0`；
传递解析得到 x `0.5.1`、async `0.22.4`、moonback `0.8.5`，均按安装元数据核查 Apache-2.0。
不再使用单独 adapter module 或局部 `moon.work`，也不再声称静态安装不会获取 UI 依赖。
核心编译仍由实际包导入关系决定；native/Wasm 的核心测试不作为浏览器交互证据。
发布与独立消费者的当前状态见 [接入说明](PUBLISHING.md)。

固定查阅源码 commit 为 `c6bbd1b3b649d5f6ea6b21e6c42f8003ec41c367`：
[模块元数据](https://github.com/moonbit-community/rabbita/blob/c6bbd1b3b649d5f6ea6b21e6c42f8003ec41c367/rabbita/moon.mod)、
[公开 SVG 接口](https://github.com/moonbit-community/rabbita/blob/c6bbd1b3b649d5f6ea6b21e6c42f8003ec41c367/rabbita/svg/pkg.generated.mbti)、
[HTML 事件桥](https://github.com/moonbit-community/rabbita/blob/c6bbd1b3b649d5f6ea6b21e6c42f8003ec41c367/rabbita/html/attrs_event.mbt)。
这个版本的 SVG Attrs 不公开 on_*，所以事件接在公开 HTML 容器上。

## 已运行的验收

下表保留 G2.1 的首次验收结果；M2 本轮的 adapter 14/14、资源隔离与独立发布包验收见 [M2 记录](MILESTONE_M2.md)。

| 检查 | 实际结果 |
| --- | --- |
| 根 `moon check --target all` | 通过，7 条既有 Ref 警告、0 error |
| 核心定向回归 | wasm / wasm-gc / js / native 各 **370/370**；含17个本片新增测试 |
| Rabbita workspace 核心 JS | 同一组定向回归 **370/370**，使用局部 x 0.5.1 |
| adapter JS | check 通过，**7/7** 测试；示例 build 通过，只有既有依赖警告 |
| 最终接口与格式 | 根和 adapter 的 info/fmt 通过，新增/变更 mbti 已审，UI 依赖隔离 |
| 原有静态示例 | main/preview/gallery native 全部 exit 0；preview 与 gallery 的已保存 SVG 均逐字相同 |
| 真实 Chrome 155 | 下列 **11 项**通过，页面错误 **0**；桌面与窄视口截图已视觉检查 |

浏览器检查覆盖真实 SVG namespace/小数几何、悬停与点击更新状态、双图隔离、图例与命中同步、
数据更新后的新数值、三次移除/挂载不重复发事件、滚动及外层 padding/border、
letterbox 空白区拒绝和响应式 CSS 命中半径；UI整理后额外检查悬停不移动图例/卡片、375px无横向溢出，
图例同时覆盖键盘和鼠标操作。运行使用真实鼠标事件，结束时关闭其临时 HTTP 服务和浏览器。

核心定向命令（仓库根目录）：

```sh
moon test drawing backend/svg scene/drawing_wbtest.mbt \
  scene/figure_test.mbt scene/category_test.mbt \
  scene/statistics_test.mbt scene/image_test.mbt scene/date_test.mbt \
  scene/autoscale_state_wbtest.mbt scene/grid_axis_regression_test.mbt \
  scene/legend_position_test.mbt scene/legend_position_wbtest.mbt \
  tests/api/readme_examples_test.mbt tests/api/usability_test.mbt tests/api/drawing_export_test.mbt --target all
```

浏览器命令与 Playwright 安装步骤见 [adapter 验证说明](../rabbita/README.md#develop-and-verify)。
本地详细日志保存在 `.moonagent/checkpoints/G2-2026-10-24/`；
最初浏览器 report.json、demo.png、mobile.png 在 `.moonagent/checkpoints/G2-browser-acceptance/`；
UI整理后的当前11项结果与截图在 `.moonagent/checkpoints/G2-ui-acceptance/`。
这些忽略目录不随仓库分发，公开命令可复现。没有把历史两万余项全套测试称为本轮结果。

G2.1 已闭合首个交互场景，M2 已补齐多图资源作用域与独立消费版本包。
后续可按用户需求补键盘/触摸、缩放平移、更多图表命中与大数据性能，逐个场景验收。
