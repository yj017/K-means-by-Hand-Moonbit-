# 图表能力与交互缺口调查

调查日期：2026-10-25。基线为实际发布的 **Lampese/mathplotlib 0.3.0**，
源码提交 `2fb8bcfc54a6a071dec0a83e9ba1d054db823c4c`。
本页按能完成的绘图任务区分静态能力、交互适配与便利入口，不按 API 数量计算完成率。

**这是固定 0.3.0 基线。** 后续 0.4.0 已增加分组/堆叠柱、真正环形图和 nearest 标量热图语义交互，
见[新图表指南](M3_CHARTS.md)。下表保留调查时的结果；最新状态见[能力页](CAPABILITIES.md)。

## 当前结论

常见二维图的静态实现比浏览器交互覆盖更广。热图、箱线图、小提琴图、误差棒、
填充面积、堆叠面积、二维直方图与六边形分箱已有实际绘制路径，不能算成没有实现。
分组/堆叠柱与真正环形图则缺少完整的几何模型或公开入口。

以下核对参考 [Matplotlib 常用图类](https://matplotlib.org/stable/plot_types/index.html)，
以本项目源码和实际运行结果为准，不要求复刻其参数集。

| 图表或场景 | 0.3.0 静态能力 | 0.3.0 浏览器适配 | 尚需补齐 |
| --- | --- | --- | --- |
| 折线、散点 | 已实现 | 已验收；折线可显式开启横轴吸附 | 后续按实际场景扩展 |
| 普通柱、横柱、直方图 | 已实现 | 整块矩形命中、系列/分类/值；直方图有区间和频数 | 多系列布局见下一行 |
| 分组柱、堆叠柱 | 缺完整入口和几何支持 | 没有对应完整语义 | 柱宽、组内位置、非零基线、累计布局和实际分段数值 |
| 饼图 | 已实现 | 扇区命中、分类/值/占比 | 环孔见下一行 |
| 环形图 | 缺正式支持 | 饼图命中包含圆心，不能直接复用为环孔 | 真正环扇区、透明孔、孔内不命中 |
| 标量热图、矩阵图 | imshow/matshow 已实现 | 没有单元格命中 | 原始行、列、值和格子范围；行列标签与数值展示工作流 |
| pcolor/pcolormesh、二维直方图 | 已实现 | 没有单元格语义命中 | 保存原始格值、边界或 bin 频数；避免从颜色反推 |
| hexbin 六边形分箱 | 已实现并返回分箱数据 | 没有六边形命中 | 分箱轮廓与计数/聚合值提示 |
| 面积、置信带、堆叠面积 | fill_between/stackplot 已实现 | 填充区域没有命中 | 上下边界、原始系列值和累计边界分别保存 |
| 误差棒 | 对称 x/y 误差已有 | 没有数据项命中 | 提示中心与误差范围；非对称误差、端帽样式为另一个能力扩展 |
| 箱线图 | 基础统计与横竖向已有 | 没有箱体/须/离群点语义 | 中位数、四分位数、须和离群点提示；位置/宽度等便利设置 |
| 小提琴图 | 已有位置、宽度、单侧、分位数与带宽等参数 | 没有图形语义命中 | 分布体和已有统计量提示，代表性应用示例 |
| step/stairs、stem、ECDF | 已实现 | 部分退化为普通线点命中 | 保留原样本/区间/概率；填充 stairs 目前无命中 |
| 等值线、向量/流线、三角网格 | 已有相应实现 | 线等值线等可命中生成顶点；填充图形等没有完整语义 | 等值级别、向量和网格原值等专门信息 |
| 极坐标/雷达、3D、动画 | 没有正式投影或运行时支持 | 未提供 | 作为独立后续目标，不计入本轮 M3 |

普通柱的公开入口只有点数组、颜色和系列名，横柱也没有位置宽度/起点配置；
渲染器按当前点间距生成柱宽，并从默认基线起画。
手工偏移坐标或使用 Polygon 拼图不算完整分组/堆叠柱能力。
对比参考：[Matplotlib bar 的 width/bottom 与堆叠说明](https://matplotlib.org/stable/api/_as_gen/matplotlib.axes.Axes.bar.html)。

当前 Pie 入口仅有值、标签、颜色和起始角；模型没有内半径。
在饼图上盖白圆不能表达透明环孔，也不能修复圆心命中。
参考：[Matplotlib 环形图示例](https://matplotlib.org/stable/gallery/pie_and_polar_charts/nested_pie.html)。

## 本次实际验证

从 0.3.0 正式 ZIP 解压到仓库外的独立 workspace，分别在 native、wasm、wasm-gc、JS
运行 19 个代表性输入。每个输入都断言 `to_drawing().svg() == to_svg_checked()`；
实际输出再由 XML parser 验证为 SVG。四目标均成功，目标数量和 SVG 长度也一致。

| 代表性输入 | 命中 targets 数量 | 解释 |
| --- | --- | --- |
| line、scatter、bar、barh、histogram、pie | 各 3 | 已有对应 HitKind 和本图元的语义数据 |
| heatmap、pcolormesh、hist2d、hexbin | 各 0 | 可出图，未收集单元格/分箱目标 |
| boxplot、violin、errorbar、fill_between、stackplot | 各 0 | 可出图，未收集对应图元目标 |
| contour | 18 | 生成后的线顶点；不是等值级别提示 |
| quiver | 0 | 可出图，未收集向量目标 |
| stem | 9 | 杆端点与 Scatter 等构成原语；不是 3 个完整数据项 |
| ecdf | 6 | 生成后的阶梯顶点；不是原始样本/概率专用语义 |

这些数量只描述固定输入，不表示图表的全部参数都已验收，也不是整体完成率。
`targets.length() > 0` 不能证明高级图表已适配。
本轮未重新运行全项目测试；没有修改生产绘图代码。

可复核的[输入与复现方法](audits/chart-coverage-0.3.0/README.md)、
[四目标结果](audits/chart-coverage-0.3.0/report.json)随文档保存。

## 源码依据与下一步

- [Drawing 命中类型](../drawing/target.mbt)：当前六类 HitKind。
- [SVG panel 分发](../backend/svg/panel.mbt)：只有 line/scatter/PathCollection/bar/barh/pie 分支采集目标。
- [图像单元格绘制](../backend/svg/image.mbt)与[PNG 分支](../backend/svg/image_png.mbt)：
  nearest 使用逐格矩形，none 和平滑插值在适用坐标上走 PNG 路径。
- [柱入口](../scene/axes.mbt)、[横柱入口](../scene/artists.mbt)、[柱几何](../backend/svg/bar.mbt)。
- [饼图入口](../scene/pie.mbt)、[Artist 模型](../scene/artist_model.mbt)。
- [堆叠面积](../scene/stackplot.mbt)、[填充](../scene/fill_between.mbt)、
  [箱线](../scene/boxplot.mbt)、[小提琴](../scene/violin.mbt)、[误差棒](../scene/errorbar.mbt)。

下一里程碑为 [M3：常用图表扩展与矩阵交互](MILESTONE_M3.md)，
优先推进规则标量热图、分组/堆叠柱和真正环形图。
其余上表缺口保留为后续工作，不因建立 M3 就标为完成。
