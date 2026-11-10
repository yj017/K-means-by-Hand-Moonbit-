# M16：极坐标与雷达的原始数据提示

2026-10-26启动，目标0.17.0。基线为已实际交付的0.16.0正式源
`99964396315269ebf7765c7437ab7258aa339b8e`。核心与adapter已合，外部consumer专项通过；
页面完整场景和中央回归已通过，独立实际检查无剩余反例；
最终源与证据已核对；0.17.0已实际发布，clean包、全新registry与GitHub附件核验均通过。

本片接续M15静态图，补原始角度、半径与雷达类别的点提示，以及与实际圆盘一致的命中范围。
保持现有出图与调用方式，应用可继续更新数据、切换方向/系列和重挂载。

## 固定范围

- [x] 一个`HitKind::Polar`；原theta弧度、原radius/value、原panel/artist/input索引与调用label。
  雷达类别按该次radar调用及原i快照，不从后来修改的刻度或图例推断。
- [x] 两种命中模式都按投影后原采样点的实际物理距离；不沿横轴或角度跨圆吸附，不在弦上插值。
  零半径保原角度，缺失保原索引洞，闭合不增加第N个样本，域外中心不生成命中点。
- [x] 只捕获实际可见散点和非零绘制弦所关联的端点。无绘制线段的孤立点、零线宽、零尺寸等保静态。
  重合点沿既有稳定选择次序，不合并原数据。
- [x] 同次绘制采集真实cx/cy/R，Drawing按候选panel做圆盘门控；巨大命中半径也不能越过圆盘，
  同图普通面板或另一极坐标面板仍可命中。圆记录随帧不可变，无SVG反推观测值。
- [x] Rabbita默认提示显示Theta (rad)/Radius及可选Category；可自定义中文/单位。
  私有实际CTM映射处理受支持的均匀缩放、letterbox、容器和SVG自身border/padding；
  极坐标高亮也裁剪到本帧圆盘。375px布局与现有图表交互保持。

本片不含线段插值提示、雷达填面、极坐标柱形、缩放/拖拽、非线性径轴或一般投影框架。
不承诺非均匀或skew CSS变换的新距离语义。具体责任与小接口在执行检查点所指active scope冻结。

## 实施与验收

- [x] producer24源、browser14源/2依赖与独立10源的短只读设计；原theta/r、类别调用归属、
  逐panel门控、CSS viewport及高亮边界已定；草案未当成实现通过。
- [x] M15 actualaudit30f5fc确认正式源999从builder到网络审计HEAD/gitclean不变，已解除冻结。
- [x] 独立owner从正式999创建分支；early8115655→Root8468eb7，14生产/2预期接口/11tests已逐SHA审合。
  最小修aede628→Rootbe3bee7，保留三个实际反例并修复：闭合`[A,A,B]`漏原0、略超max
  被屏幕舍入收回、fractional圆的边界采样遗漏。三份旧Polar SVG及普通控制保持。
- [x] 原i/theta/r/category、零/缺失/域外/闭合N、旧帧与clear、两mode真实圆盘和混合面板的独立Native/JS核对。18actualXML、8同target旧SVG逐字，
  16源/110proof与3immutable archives经Root逐SHA核同，无剩余blocker。
- [x] 真实双卡DOM与CSS完整专项：16项、38组整数请求/72实际handler事件、0错误；
  包含ignored普通+两个polar混合fixture，正式runner默认14项。Root目视desktop/375，
  七UI源及三个adapter逐SHA核同，实际PNG111141字节与中央截图逐字一致。
- [x] 外部consumer Native/JS/Chrome52903均终0：59项、8实际整数事件、0页面错误；
  默认原弧度/半径、中文雷达类别、点击与圆形高亮、375px及既有图表接入通过。
  actual info/fmt21032均0，两私有compiler接口逐字不变。
- [x] owner四目标Native67/其他各66，Rabbita51；12同target旧SVG逐字保持。
- [x] 一次中央全套9480终0/267.4秒：W/WG22658、Native22662、JS22718。
  actualinfo/fmt与16JS构建53079、postlude64089均终0，16页面Chrome204/0错误、
  三static、结构/文档/预期接口全部通过；23steps全0，未重复全套。
- [x] 正式源cedbf16：clean22726、publish92686、公开success935e50、全新registry37462、
  GitHub create44289与完整下载92054均终0。612安装源同正式ZIP、四static/Chrome59与8整数事件；
  四附件完整字节/大小/digest/tag核验通过。finalaudit2bb881确认HEAD/gitclean全程不变后解除freeze。
  [v0.17.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.17.0)与
  [完整交付记录](archive/migration-status-through-2026-10-26-m16.md)保留证据。

数值圆盘边界只采用与投影运算一致的binary64舍入界，与CSS缩放和用户命中半径无关；
略超原径轴上限的数据另作严格过滤，明显圆外点和包围框空角保持不可选。

[当前执行检查点](MIGRATION_STATUS.md) · [极坐标指南](POLAR.md) · [能力](CAPABILITIES.md) · [路线图](MIGRATION_PLAN.md)
