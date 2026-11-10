# M5：矩形网格与二维计数分箱

创建日期：2026-10-25。状态：**已验收并交付0.6.0。**
继续复用已有静态图，目标版本 0.6.0。

## 平面标量网格

- [x] 1D 严格单调边界的 flat `pcolor/pcolormesh`，可在整个实际矩形内 hover/click。
- [x] `Heatmap + CellInfo` 保留原始行列、标量及双方向边界；掩码不压缩原索引。
- [x] 同次绘制捕获真实四角及裁剪；mask/NaN/Inf、归一化拒绝和透明格没有有效值。
- [x] 非均匀、反向边界、非线性轴、图例、CSS、更新与多图都有实际验证。
- [x] Polygon 元数据使用原数组身份，构建采用序号／游标及验证；前置 image 或 contour 重写不串。
  不通过每格从头扫描全部记录查找，不设脆弱的耗时测试阈值。

## 二维计数直方图

- [x] 现有无权重 `hist2d` 返回值不变；增加 `Histogram2D` kind，复用 CellInfo 双区间。
- [x] 原计数在 Scene 分箱后保存，提示同时提供 x/y 区间和 Count；不从颜色恢复数值。
- [x] 覆盖零计数格、最大边界进最后分箱、缺失输入、原行列和自定义提示。

## 普通柱的有效域边界

- [x] 修复旧 bar/barh 在 Logit 上端点无效、区间却跨过有效视图时被丢弃的遗留行为。
- [x] 复用现有分段柱区间逻辑，同次绘制与命中保持一致；已有合法端点／线性 SVG 保持逐字一致。

## 交付

- [x] 最终四目标全套、相关组件、三图和dirty ZIP演练通过。
- [x] clean正式包、实际registry独立消费与正式发布/附件核验。

本片不含 `_grid` 曲线边界、nearest 边界推导、Gouraud、hexbin、权重和密度扩展。
曲线网格后续必须携带真实数据角点，不以包围框冒充二维分箱区间。
执行状态与精确下一动作见 [检查点](MIGRATION_STATUS.md)。

[使用指南](MESH_INTERACTION.md)与[三图源](../rabbita/cmd/grids/main.mbt)已提供。
全套Wasm/Wasm-GC/Native各22,410，JS22,443全部通过；中央相关回归四目标各1,874/1,874；组件JS26/26；三图实际Chrome11组通过，无页面错误。
6份网格静态SVG与基线逐字一致，12份旧柱SVG控制亦逐字一致。
独立dirty ZIP演练、clean正式ZIP与实际registry消费者均通过四目标静态+Chrome13项。
正式源 `b563204ab9d021f7660c1ab0166104972ad2e4a8`；Mooncakes0.6.0构建成功，
531份安装文件逐一等于正式ZIP。[GitHub v0.6.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.6.0)
四附件回下载、摘要与tag均已核验，未覆盖旧版本。
