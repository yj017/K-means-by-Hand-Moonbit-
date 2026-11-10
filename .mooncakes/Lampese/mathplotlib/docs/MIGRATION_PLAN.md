# MoonPlot 能力路线图

更新时间：2026-10-26。

目标是一个可用、易接入、可逐步完善的 MoonBit 画图库。Matplotlib 是能力与行为的参考，
不再要求复制其全部 API、Python 动态协议或所有参数。实现可以采用适合 MoonBit 的类型和调用方式。
以“用户能完成一个绘图任务、能复现结果”验收，不用 API 数量或测试数量推算整体百分比。

## 四个大目标

| 目标 | 用户得到什么 | 验收边界与当前状态 |
| --- | --- | --- |
| **G1：基础二维 SVG 可用版（M1）** | 折线、散点、柱状图；标题、轴标签、刻度、网格、图例；可运行多图示例 | 已验收：修复 grid 单轴与柱宽范围错误、补四角图例，实际出图与相关四目标回归通过 |
| **G2：Rabbita 交互 DOM** | 在 Rabbit-TEA/Rabbita 应用中返回可组合的 DOM，响应悬停、点击和数据更新 | G2.1/M2 已验收；0.3.0 补齐六类图表语义命中与自定义提示，见[提示功能](TOOLTIPS.md)；其余交互缺口逐项推进 |
| **G3：常用数据与科学绘图场景** | 日期趋势、分类对比、分布统计、热图及更复杂的组合图 | 已有大量静态实现；[M3](MILESTONE_M3.md) 接续热图交互、分组/堆叠柱与真正环形图 |
| **G4：导出、接入与持续交付** | 清晰的安装和错误信息、稳定的库入口、更多输出方式、小步发布 | SVG、单一 Lampese/mathplotlib module 与独立接入验证；0.17.0 已交付；PNG/PDF与性能按需推进 |

G4 的文档和质量工作随每个里程碑推进。M1 与 G2.1 已完成验收；后续继续按具体场景扩展 G2/G3。
G3 不需要等全部图表参数一致才交付；其内部顺序由实际使用需求决定。

## M1：现在版本加少量特性即可使用

用户已选择“基础出图稳定、少量易用性特性”。本轮范围固定为：

1. 排查并修复先前三图工作流的真实错误。定位结果是默认 `which="both"` 时
   `grid(axis="y")` 被错误拒绝；不需要通过手动刻度绕开。
2. 修复实际视觉检查发现的柱状图越框，范围计算与绘制共享数据宽度规则，包含水平柱和单柱。
3. 为现有图例增加四角位置。默认仍为右上；保留自动/显式条目行为，每个 Axes 独立设置。
4. 提供运行后可直接保存的 Gallery，并检查实际 SVG 和渲染图；保持原有两个例子可用。
5. 通过相关新旧测试、四目标检查、接口检查；用少量现有测试冒烟直方图、图像与日期入口。
6. 记录已验收场景及限制，提交可复现的源码和预览。

逐项结果维护于[能力与验收清单](CAPABILITIES.md)；具体运行命令和结果见[M1 验收记录](MILESTONE_M1.md)。
M1 不要求独立 PNG/PDF 后端、交互 DOM、3D、动画或完整字体/TeX 排版。

## M2：可接入的浏览器交互绘图

在 G2.1 基础上保留已完成的 hover/click、图例、数据更新、响应式与 UI，
补齐 SVG ID/local URL/href 链隔离；用双图渐变/裁剪的同页真实像素验证重绘、换序和重挂载。
发布 v0.2.0 的两个精简模块 ZIP 与显式独立 workspace，仓库外四目标静态及真实浏览器消费验收。
[范围、命令与限制](MILESTONE_M2.md)已固定；缩放、平移、框选和触摸不属于 M2。
0.2.0 原命名空间权限预检失败，已交付 GitHub 源码版本包；用户随后明确要求使用 Lampese/ 前缀发布，
0.2.1 将核心与组件合并为单一 module。当前安装路径与发布状态见 [接入说明](PUBLISHING.md)。

## 后续如何推进

每个后续切片先明确一个用户场景、输入与输出，复用已有能力，提交前验证真实结果。
发现失败就定位并修复，不能把一个未验收的实现当完成，也不因为失败而默默停滞。
公共 API 只在有实际用途时扩充；保留现有调用可用，并在生成接口中审查变更。

当前架构为 Scene → render IR → SVG；`to_drawing()` 在同次绘制中收集命中点，
Rabbita adapter 将 SVG 转成公开节点树，复用现有坐标和布局算法。
Rabbita 组件位于同 module 的 JS-only 子包；模块安装统一解析依赖，核心包不 import UI，静态输出继续支持原平台。

## 当前资料与历史参考

- [当前执行检查点](MIGRATION_STATUS.md)：下一动作、实施与验收状态。
- [现有能力](CAPABILITIES.md)：用户可调用的功能和实际限制。
- [详细使用指南](USAGE.md)与[接口行为参考](COMPATIBILITY.md)。
- [原完整 API 迁移计划](archive/migration-plan-api-history.md)与[历史执行记录](archive/migration-status-through-2026-10-24.md)：保留历史，不作为现行任务清单。
- [历史 API 对比](MIGRATION_PROGRESS.md)：原口径与数据仍可查，不代表当前画图库整体完成率。

## 0.3.0：常用图表的值提示

在同一次绘制中捕获柱形/横柱/直方图的矩形、饼图扇区及其语义数据；
折线增加按屏幕横轴选择真实样本的模式。Rabbita 组件提供默认提示和自定义内容/样式入口，
应用拥有日期、单位与本地化格式。范围、示例和实际验收见 [提示指南](TOOLTIPS.md)。
不为接入这些能力重写 SVG 坐标或恢复全 Matplotlib API 迁移。

## M3：常用图表扩展与矩阵交互

本轮先对 0.3.0 做了[实际调查](CHART_COVERAGE.md)：静态实现与交互覆盖分别记录，
19 个代表性图类输入在四目标均生成可解析 SVG，命中数据的缺口可复现。

M3 三项目标已实现：规则 nearest 标量热图的整格提示、多系列分组/正负堆叠柱、真正透明环孔的环形图。
四目标相关回归与五图真实 DOM 已验收；[范围与结果](MILESTONE_M3.md)、[使用指南](M3_CHARTS.md)记录具体边界。
0.4.0 clean 包、实际 registry 消费与正式发布均已完成。

## M4：统计图与区间交互

[M4](MILESTONE_M4.md) 已合入误差棒、面积/置信带/堆叠面积和箱线图交互，
复用现有统计计算和静态 SVG，同次绘制捕获真实几何与原始数据。
最终全套、五图DOM、正式包/实际registry消费和附件回验均已通过，0.5.0已交付。

小提琴、不规则网格/分箱语义和更复杂科学图保留为明确后续项。
已有静态绘制能力继续复用；只把实际验收的交互场景标为完成。

## M5：矩形网格与二维计数分箱

[M5](MILESTONE_M5.md) 已合入 flat pcolor/pcolormesh、hist2d 双区间计数提示，
以及旧普通柱跨 Logit 有效视图的遗留边界。四目标全套和三图 DOM 已通过，0.6.0已发布并完成真实registry与四附件核验。

## M6：六边形分箱与小提琴分布

[M6](MILESTONE_M6.md)继续补齐已有静态图的交互语义：hexbin实际六角整格与原计数/聚合值，
violin真实密度体与统计线。两者复用既有统计和绘制，不在组件中重算分箱或密度。
独立实现及数学复审已合入，0.7.0已发布；全套、四图DOM、仓库外实际registry和GitHub附件均验收通过。
已修正旧hexbin分桶与绘制轮廓错位、邻格重叠及空隙：同一交错格点定义决定分箱与实际六角顶点。

## M7：离散曲线

[M7](MILESTONE_M7.md)接续step/stairs/ECDF的原采样、区间和概率语义，保留已有静态输出。
公共Line快照guard与实际valid-run捕获由单一owner维护；0.8.0已实际发布，四目标全套、八页面Chrome98项、clean包/实际registry与GitHub四附件均通过。

## M8：Stem 杆线图

[M8](MILESTONE_M8.md)接续原stem样本的真实杆段与头部，统一原head值、起点与横竖方向，保留既有静态输出和component artist身份。
共享只读源表避免每杆复制全数据；0.9.0已交付，中央各22505/JS22550、九页面Chrome110项、独立复审、clean包/实际registry与GitHub四附件均通过。

## M9：Quiver 向量箭头

[M9](MILESTONE_M9.md)接续已有向量场的实际箭杆与双箭翼，提示原始位置和U/V分量。
保留既有计算、静态三线段箭头、签名与Container；首片不计算magnitude或扩Barbs/Streamplot。
0.10.0已实际交付：四目标全套、十页面Chrome122、clean包/全新registry四目标Chrome28、566安装源与GitHub四附件完整下载全部通过。

## M10：Barbs 风羽图

[M10](MILESTONE_M10.md)复用已有basic/options展开图元，补原pivot前输入位置、U/V与原索引；不新增Part、magnitude、Container或一般样式参数。
包含两个已证实修复：zero/empty误改前一Line的series、高级派生非finite/不可表示计数在转换循环前报错。
0.11.0已实际交付，正常静态输出与有效前缀错误行为保留；独立复审、四目标全套和11页面Chrome134项通过，573全新安装源、四目标/Chrome32与GitHub四附件完整下载核验通过。

## M11：线等值线的级别提示

[M11](MILESTONE_M11.md)接续regular contour与tricontour真实线段的精确level/series，保留原生成path槽及默认inline标签拆线后的对应关系。坐标表示生成边的几何中点，不冒充原网格观测；filled多环/孔洞独立后片。
0.12.0已实际交付：四目标全套、12页面Chrome148项与独立Native/JS几何和生命周期复审全部通过；clean包/581份全新registry源、四静态/Chrome36与GitHub四附件完整下载均核验通过。

## M12：填色等值区

[M12](MILESTONE_M12.md)接续已有contourf/tricontourf的多环、孔洞和区间代表值提示。单Polygon与Compound分别保留真实nonzero/evenodd规则，原逻辑band槽不冒充layers或展平环索引；实际填色只在plot内交互，保留旧SVG margin行为。
目标0.13.0，已从正式0.12源ae1ce6b实现实际区域捕获。真实双卡Chrome14项与外部consumer41项通过；独立Native/JS复审无blocker，四目标全套与13页面Chrome162项通过。0.13.0已实际发布：clean包/590全新registry源、四静态/Chrome41与GitHub四附件整下载均过，正式源87a在整个网络audit中保持不变。

## M13：三角网格着色的原面与顶点信息

[M13](MILESTONE_M13.md)接续已有tripcolor/direct/wrapper，显示原逐面标量或旧顶点均值，保留原面槽和实际有序顶点三元组。复用actual Polygon与nonzero FilledRegion，不伪矩阵行列，保mask洞与原normalization/均值/Unit/0Container/SVG。
0.14.0已实际交付：独立Native/JS复审、中央四目标全套与14页面Chrome176项、clean包/600份全新registry源/四静态/Chrome46和GitHub四附件整下载均过；正式源1215721。

## M14：连续流线的生成场值

[M14](MILESTONE_M14.md)复用streamplot/mesh/style-grids，接续实际body线段、原seed尝试槽与生成edge，显示原有限中点的双线性U/V及同次style颜色标量。保旧积分/样式/返回Set/1Container和SVG；箭头首片保静态。
0.15.0已实际交付，正式源67c0951；独立复审、中央四目标与15页面Chrome190、clean包/601安装源/四静态Chrome51及GitHub四附件完整下载全部通过。

## M15：基础极坐标与闭合雷达

[M15](MILESTONE_M15.md)从实际0.15源67c0951扩展typed极坐标折线、散点和闭合轮廓雷达。
先提供真实圆形投影/裁剪的静态SVG与RabbitaDOM，应用可更新数据和切换系列；全部polar捕获禁用，
原始theta/r点提示与圆盘CSS门控独立M16。0.16.0已实际交付，正式源9996439；
独立Native/JS复审、中央四目标/16Chrome204、clean包/607安装源/四staticChrome56和GitHub四附件完整下载均通过。

## M16：极坐标原始数据提示与圆盘命中

[M16](MILESTONE_M16.md)从实际0.16源9996439补原theta/r、原索引、调用label与雷达类别，
两mode按投影后物理近点，逐候选panel圆盘门控；Rabbita提供默认/中文提示、准确client映射和圆内高亮。
0.17.0已实际交付，正式源cedbf16；独立复审、中央四目标/16Chrome204、clean包、
612全新registry源/四static/Chrome59和GitHub四附件完整下载全部通过。

## M17：极坐标柱形／玫瑰图

[M17](MILESTONE_M17.md)继续补常用图形：显式单一角宽、零起点的极坐标柱形，保留原θ/r与输入索引。
同次绘制采集实际扇形面积，悬停/点击显示原值；全圆、跨零角、方向/偏移与径上限裁剪属于首片。
目标0.18.0；实现已启动，验收与分发尚未完成。
