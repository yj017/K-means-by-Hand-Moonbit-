# M15：极坐标折线、散点与闭合雷达

2026-10-26完成并实际交付0.16.0。基线为已实际交付的0.15.0正式源
`67c095118a45d27f6f3ab3d8fb3d3dff2a0e8877`。实现、专项、中央与实际交付均已完成。

本片先交付可用的静态 SVG 和可组合 Rabbita DOM；应用可以更新数据、切换系列和重挂载。
原始角度/半径的点提示与圆盘指针门控留下一片，不生成笛卡尔观测式提示。

## 固定范围

- [x] typed `PolarAxes` / `PolarDirection` 与显式 `Figure::add_polar_axes`；
  极坐标折线、散点和至少三维的闭合轮廓雷达，支持标题、图例、角/径刻度标签。
- [x] 原theta/r数据保留在 Scene；可选投影 IR 与专用 renderer 复用既有 Line/Scatter、
  样式和 SVG writer，不引入一组通用 Artist 变体或投影字符串框架。
- [x] 角输入为弧度，默认右为零、逆时针；有限 offset 与 typed 方向可设置。
  非方形面板使用同一物理半径，圆心/半径统一决定数据、网格、边框和真实圆形 SVG 裁剪。
- [x] 线性径域从0到rmax；显式上限有限且大于0，自动取联合有效非负样本最大值，
  空/全零回退1。非finite/负半径作为缺失，折线断段、散点跳过，零半径合法。
  超界数据保原值并由圆盘裁剪；无法有限投影时保守断段。
- [x] 折线连接投影后样本的直线弦。仅整组有效时绘制合成闭合边，原数组仍为N点；
  雷达不增加额外原样本、不自动旋转面板，同面板各系列分类表须一致。
- [x] data-only circle clip资源按面板隔离。整个polar分支无命中目标；
  混合 Figure 中普通面板保持原范围、布局、provider/cache和交互行为。
  不支持的笛卡尔设置或图元在checked渲染明确报错。

本片不含雷达填面、维度独立归一化、非零rmin/环域、Log径轴、角扇区、任意图元投影、
插值曲线或新的hover元数据。具体实现责任合同在当前执行检查点所指的active scope中冻结。

## 实施与验收

- [x] 只读准备：producer31必要source SHA与A/B设计，独立五角度公式、方向和真圆/闭合反例要点；没有把准备当新功能通过。
- [x] 独立owner从精确67建立`codex/m15-polar`，335bcb7首批核心/接口已审合为1b48850，三实际SVG及两旧控制Native85721通过。后续50ca4ed明确拒绝继承axis-off设置，审合为a0e018d；真实before58048与after90727已保留。
- [x] 非方形cardinal/非cardinal、offset/CW、两组五维雷达、缺失/负/零/超界数据的真实SVG/圆形clip与原数组验收；普通面板控制保持。独立335 Native/JS的22新XML和4旧SVG通过，数学误差上限5.684e-14。
- [x] owner最终401883d→764770c，production固定65a1bdc→0313aa6；26源与71proof已Root核同。71159 Native103/其余各101/Rabbita50、11186十二同target旧SVG均0；actualinfo/fmt/structure/指南links0。独立335/50的19源72proof和65的19源44delta proof、三archive均Root核同；实际Native/JS反例before/after与全局grid/margin、clear旁支闭环，无剩余blocker。
- [x] 双卡UI1efb4e3真实DOM更新、四独立图例、三次重挂载、资源隔离、圆形SVG实际像素与375px；最终Chrome74155 14/14、33整数事件、0errors，实际PNG已目视。
- [x] 独立consumer Native96487、JS6483与axis-off后build145a36、Chrome26756全部0；56checks含五个新极坐标组、实际SVG栅格圆裁剪和375px真圆。actualinfo79875与四文件fmt0、两private接口不变。consumer提交97f2b78。
- [x] 中央prelude57456、唯一full93615/264.29s、postlude83376全部0，23步骤；W/WG22644、Native22648、JS22701、16页面Chrome204/0errors，三静态SVG/54MD594links/structure/diff/预期接口通过。canonical polarJS4663158bytes与实际served核同，中央PNG逐字等于已目视asset。collector首复制旧22步骤计数失败已保留并修，仅重新汇总，未重跑通过的full。
- [x] 正式源9996439/push30930；clean5127/dirtyfalse/四staticChrome56，module607files/2748140bytes、source638files/2806598bytes；20owner生产/接口/guide与asset逐字。actualpublish89744/200，首public queued仅等待，第二a46bad buildsuccess/checksum同；fresh registry61533的607安装源逐字/四staticChrome56。GitHubcreate9181/完整四附件47226/bytes/digest/size/tag全同，finalaudit30f5fc确认全过程HEAD999/gitclean不变，之后解除freeze。

[GitHub v0.16.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.16.0)。后续原theta/r与类别提示见[M16](MILESTONE_M16.md)。

[当前执行检查点](MIGRATION_STATUS.md) · [能力](CAPABILITIES.md) · [路线图](MIGRATION_PLAN.md)
