# M17：极坐标柱形与玫瑰图

2026-10-26启动，基线为已交付0.17.0正式源`cedbf1651a8645fe3b77cce91fdfaa708437bdd0`，
目标0.18.0。核心、DOM与专项已完成；正在收尾中央回归和0.18.0实际发布。

## 固定范围

- typed `PolarAxes.bar(theta, radius, width~)`，统一角宽为弧度，中心对齐、零起点填充扇形。
- 原θ/r与输入索引、系列名保持；非有限或负半径保洞，零半径无正面积命中。
- 自动径上限合并所有极坐标系列；显式上限裁掉域外填色，可见部分仍显示原始值。
- 同次SVG绘制收集真实扇形区域；两种命中模式均按面积，空角不因大hit_radius产生柱命中。
- 复用M16圆盘、实际CSS映射与tooltip；完整2π为真圆，方向/偏移、数据更新、图例和375px可用。

角宽首片要求有限且`0 < width <= 2π`，与长度错误在追加图元/推进颜色前原子拒绝。
半径为原值的线性高度，面积自然随平方变化；不自动分箱、归一化或开平方。
首片不含可变宽数组、每柱颜色数组、bottom/堆叠、雷达填面、非线性径轴或通用投影框架。

## 实施与验收

- [x] M16实际交付已核验，正式基线与最小合同固定，三个独立工作区分工。
- [x] Drawing/默认tooltip底层：PolarBar、圆盘门控、扇区面积及laterPolar物理overlay；
  fractional圆实际失败保留，窄舍入修复后Drawing四目标各64、RabbitaJS54通过。
- [x] Scene/IR/SVG与原始数据归属已合，相关四目标各38通过，旧三份polar Native SVG保持。
- [x] 独立复审实际发现圆东边界被矩形舍入先排；Root窄修后重跑原Native/JS反例通过。
  子代理额度用尽后的剩余核对由Root接手，不冒称独立完成：Native/JS各6实际SVG数学场景、
  各426个明确内部/空区查询通过；来源变异/类型/原子输入等随own四目标验证。
- [x] 真实双卡DOM14项、27组整数事件、0errors；实际SVG填色、全扇形、原值、CW、完整圆、
  后绘点、更新、四图例、三重挂载、border/padding缩放、375px默认/中文提示均通过。
  已移除未实现的可选fixture入口，中央正式runner也已通过14项。
- [x] 外部consumer Native/JS/Chrome52330通过：63项、9新bar整数事件、0errors；
  两mode全扇形/原始值/空角与圆外、点击clip、375中文。actualinfo/fmt5631及两private接口通过。
- [x] 中央23steps全0：实际info/fmt、16JS、唯一全套70573（269.77秒）
  W/WG22678、Native22682、JS22740；16页面Chrome204、三静态、文档/结构/预期接口均通过。
- [ ] clean包、实际Mooncakes与GitHub交付。

[执行检查点](MIGRATION_STATUS.md) · [极坐标指南](POLAR.md) · [能力](CAPABILITIES.md)
