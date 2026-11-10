# M9：Quiver 向量箭头交互

创建日期：2026-10-25。状态：**已验收交付**。0.10.0已实际发布Mooncakes与GitHub。
用户要求持续按绘图能力推进；本片复用已有quiver，不增加Barbs/Streamplot、向量长度或一般箭头样式参数。

## 固定合同

- [x] 保留既有quiver签名、Unit返回、单artist/Container、非finite整call报错与实际SVG。
- [x] `HitKind::Quiver`，只读`VectorInfo{u,v}`与可选`HitInfo.vector`；原x/y及原输入i不变。
- [x] 通用`value`明确为原V分量；默认提示显示X/Y/U/V，不把屏幕箭长或溢出的norm当观测值。
- [x] 复用实际绘制的shaft和两wing三个Segment，不虚构填充三角面；两个mode均只命中实际线段。
- [x] 零向量、尺度域外、端点溢出和clip保持旧绘制行为与原索引洞；原数据不被clip边界替换。

## 实现与验收

- [x] points及vectors身份、不可变call源表和实际provider/context守卫，变更后保守静态，无泛化Line回退。
- [x] 同次实际三线段捕获；共享源表与逐样本O(1)回调，无逐箭全量复制/扫描。
- [x] 独立旧SVG、原u/v与负值、反轴、非线性、clip、zero与normoverflow有限分量案例。
- [x] 普通Line/Scatter/其他图层、同色多call、输入副本/旧Drawing、实际paint/clip与component身份不倒退。
- [x] 可运行DOM示例，真实shaft/wing触发默认/自定义提示，独立显隐、更新/重挂载、CSS/letterbox与375px。
- [x] 中央接口/fmt/结构、必要四目标与既有浏览器回归；独立公开consumer/实际几何复审。
- [x] clean正式包、实际Mooncakes全新安装、四目标静态/浏览器消费与GitHub四附件完整下载。

m3_donut负责精确正式0.9源上的生产实现；m4_area准备独立oracle与旧SVG；m3_browser先只写ignored草稿。
Root负责合入、公开consumer与组合测试、版本/文档和实际发布。实现、验证、发布分别记录，不提前标完成。
详见[执行检查点](MIGRATION_STATUS.md)、[能力](CAPABILITIES.md)与[安装](PUBLISHING.md)。

## 准备记录

- [x] 正式0.9源固定；producer定点旧行为packet/6SVG与16源SHA已收，全部与Root一致，实际旧targets0。
- [x] Root独立公开consumer旧Native3SVG保存通过，实际线段9/9/3和手算shaft坐标相符；此项只验证基线，不是M9命中验收。
- [x] producer首核心e475已合4403974：129task check/Native10项/旧6SVG控制/info/fmt/结构通过。
- [x] Root实际外部dirty演练静态四目标+Chrome28项/0errors，三组合四目标各3/3；三个自选旧SVG逐字相同。
- [x] producer四目标/adapter最终定向、独立复审、DOM专项与中央验收。

UI隔离编译通过，真实Chrome首轮发现runner dataset数字连字键错误，已定位修runner重跑，无生产反例；不将未完成UI标验收。
Root外部fixture已使用真实新接口通过；所有dirty演练只保留开发记录，不上传。

双卡七文件已冻结：隔离53444/info91925、真实Chrome91091 terminal0，12/12、0pageerrors。
24次实际shaft/wing MouseEvent距对应真实Segment最大1.1154CSSpx（radius2）；open-head空白点离全部9线4.4868px，实际nohit。
Root已目视真实desktop PNG1280×1015/75274bytes与手机结果，七SHA匹配final-evidence。初两轮仅runner dataset键与临时zoom被卡裁切，已保留失败证据并修正，无生产政策改动。

后续0f6530a已合60f7ca4，production自e475不变，Root25最终文件SHA一致。affected W/WG/JS各155、Native156与adapter40全部通过，24份同target旧/新SVG逐字一致；Native golden仅限本target，保留平台libm末位差的原始失败记录。
独立e475 Native/JS各18公开组、各8XML41target、Native8旧SVG、Scene2+Backend2与4096→12288targets均过，无blocker；14生产SHA与Root相同。
中央72277 terminal0：Wasm/Wasm-GC各22520/22520、Native22521/22521、JS22567/22567；info/fmt/10JS builds、结构通过。
十个真实Chrome页面122项/0errors；三个native SVG解析，preview6886/gallery14246与资产逐字；42MD/498本地链接通过。无额外mbti差异，七文件freeze不变，默认/isolated JS及实际8765资源一致。
正式源c9eb6bec526a2f6d2b1f6330a60ef616dd83a16a已push6953 terminal0；clean builder14188 terminal0，实际publish24617 terminal0/200，公开success/has_package=true/yanked=false。
全新无workspace registry94135 terminal0：566安装源逐一相同，静态四目标与Chrome28全部通过；GitHub创建35288/完整下载21859均terminal0，四附件逐字/远端digest和size/tag源码SHA全过。
[v0.10.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.10.0)。模块ZIP2258118bytes/SHA1bea6b23cbce9a240e004e22be02fbfbe7c70e335173ad8d132cf66eb7e9968f；sourceZIP2294805bytes/SHA4f1552295d07ff44b02383d0b5e83ff200a823abaf1bf42cf6788aa449cf73dd。
正式构建至网络闭环未tracked写入或commit，dirty演练未上传。
