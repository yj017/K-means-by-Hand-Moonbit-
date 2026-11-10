# M8：Stem 杆线图交互

创建日期：2026-10-25。状态：**已验收交付**。0.9.0已实际发布Mooncakes与GitHub。
继续复用现有静态stem，补原样本语义和真实杆/头命中，不扩一般格式字符串或可变Container API。

## 固定合同

- [x] 保持既有stem参数、返回Container、N+2实际artist顺序与静态SVG。
- [x] 新增`HitKind::Stem`；`point_index`是原输入i，过滤后保留索引洞，data为原head坐标，value为原head scalar，series为原label。
- [x] 复用`HitInfo.band=BandInfo(bottom,head,horizontal,false)`，保留正负方向和非零起点；不新增StemInfo或公共可变数组。
- [x] 实际Rod Segment与默认Scatter head Point共享原datum，但保留真实component artist_index；全局baseline静态，bottom不当作观测。
- [x] 两命中模式首先只选择实际杆/头；不隐式增加全panel横轴吸附，不虚构底部锚点或零长度杆。

## 实现与边界

- [x] 复用同次Line valid-run捕获、metadata/context身份、实际paint与panel clip；头在实际circle写出后回调，保留未过滤i。
- [x] call级只读carrier与Rod(i)/Heads轻量记录共享源表；每根杆不复制全N个datum，避免O(N²)。
- [x] 缺失head/location、zero-height、Log域外bottom但合法head、反向轴和跨视图杆保留真实源语义，不能由端点bbox造线。
- [x] 输入副本、实际path变化与旧Drawing快照明确处理；保持普通Line2D/Scatter与旧统计图规则。
- [x] 同色多call、图像/inline contour前缀、区域覆盖先后和真实component身份经过定向验证。

## 验收与交付

- [x] 旧stem实际SVG控制；独立公开消费/真实几何复审；受影响四目标和Rabbita定向测试通过。
- [x] 默认/自定义提示、独立显隐/更新/重挂载、CSS半径/letterbox与375px的真实DOM示例。
- [x] 中央接口/fmt/结构、最终四目标全套及适当既有示例回归通过。
- [x] clean正式包、实际Mooncakes全新安装、四目标静态/浏览器消费、GitHub四附件完整下载核验。

m3_donut负责独立worktree生产实现；m4_area准备独立oracle与旧SVG控制，精确commit后复审；m3_browser先只写ignored草稿，生产合入后再授权七文件部署。
Root负责中央合入、版本/文档、外部consumer和实际交付。M7已发布闭环；每片结果只在实际通过后记完成。
详见[执行检查点](MIGRATION_STATUS.md)、[能力](CAPABILITIES.md)与[安装](PUBLISHING.md)。

## 阶段验证

Source cf4de322已合fe9de53，owner四目标定向各133/133、adapter38/38、Native13/13，10份旧Stem+14旧离散SVG逐字相同；info/fmt/结构与预期接口变化通过。
Root三组合四目标各3/3、仓库外dirty包静态四目标+Chrome25通过；dirty包不用于实际发布。
三卡UI隔离build/info与真实Chrome12项、0errors首轮通过，七文件已冻结；实际桌面/mobile已目视。
中央40879 terminal0：Wasm/Wasm-GC/Native各22505/22505、JS22550/22550，接口/fmt/九JS构建、结构通过。
九页面Chrome共110项通过、0errors；三native SVG可解析，preview6886/gallery14246与资产逐字一致；40份MD/488本地链接通过。
默认/隔离Stem JS4504167bytes/SHA3768e880572a77db935bf3cae8293efdc31238b9642b23278b83b1ec6d0dec14一致，实际8765 HTML/CSS/JS HTTP200逐字相同。
Root已目视真实PNG。独立复审cf4de322：Native/JS各23公开组、各8实际SVG与23个真实primitive匹配、旧Native8份SVG逐字、Scene2+context1组全部通过，无blocker。4096datum/8192targets两端通过；源码确认单源表、常数view与heads全guard一次，未使用耗时阈值。11个生产源hash与Root逐一相同。
正式源95a34c3dc154f48fb3b83b7f37ecad3a0e8273c8，clean builder21070 terminal0；实际publish84366 terminal0/200，公开success/has_package=true。
全新无workspace registry51252 terminal0：560份安装源逐一相同、静态四目标与Chrome25全部通过。
GitHub创建55397与完整下载30349均terminal0，四附件逐字/远端digest和size/tag源码SHA通过；[v0.9.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.9.0)。
模块ZIP2179542bytes/SHA352a7d165124952f0d13bf988e60c9927991c88a1a1d8fbcced6fbfa008562c5；sourceZIP2212594bytes/SHA99934cca03b701938b30fe18acf0a42844b5ffb9fa6509002b3acf26e52d3a39。
正式构建至下载闭环期间未改tracked文件或commit。
