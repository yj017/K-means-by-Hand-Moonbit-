# MoonPlot 当前执行检查点

更新时间：2026-10-26。恢复先读本页。当前用户要求“先把现在的事情发个新版本”，
本轮仅收尾现有极坐标柱形／玫瑰图并发布0.18.0，不启动新图类或新milestone。

## 用户约束

实用MoonBit画图库，按能力验收，不恢复全部Python API克隆，不编造整体百分比。
已授权本地commit/push、Mooncakes Lampese/单module及GitHub发布。用户指出里程碑拆得过碎，
本次发布后停止扩展，汇报结果。root facade/owner tests/mbt<2000/actualinfo-fmt/structure保持。

## 0.18.0 现有功能与已验证

[M17](MILESTONE_M17.md)：typed PolarAxes.bar，必填统一角宽弧度、中心对齐、零起点填充扇形，
真实full2π圆。原θ/r/i/calllabel保留，等长/宽度原子拒绝，missing/负r保洞、r0无面积。
径上限先cap后ratio，可见面提示原域外rawr。Bar来源独立于Line/Scatter；宽度用于静态几何，
变异来源无旧提示；无角宽手工Bar checked unsupported。两mode实际面积/逐panel圆门控，
仅newBar允许laterPolar物理overlay；默认Theta(rad)/Radius和中文回调。无新Info/伪interval。

- [x] 基线为已交付0.17.0正式cedbf1651a8645fe3b77cce91fdfaa708437bdd0。
  Root已有commit373715b→eb00d7b→0acec48（ownerdfdd611）→b710c88，早步已push。
- [x] Root Drawing初步四目标64与RabbitaJS54；实际fractional西边界before71387保留，修复只限PolarBar。
- [x] 独立30476/5800与producer23978发现真实东边界：circlecx+R=243.8但boundsright舍入成
  243.79999999999998。Rootbefore66290保留，4eps intrinsic newBar area-bounds窄修23929终0，
  Drawing四目标65。原独立反例Root66369 Native/JS都过，不改旧Pie边界。
- [x] Root接手代理未完成tests/guide/UI（代理均额度错误，无剩余代理live）。own四目标5084各38通过；
  adapter47753通过、actualinfo/fmt/structure均0。private stub无意外，测试草稿误参/错误空角已保before并修harness。
- [x] Root补完公共数学oracle13370 Native/JS各6实际SVG、426明确内部/空区查询全过。
  首函数签名草稿编译失败只在ignored harness，保日志后修；不冒称额外独立复审完成。
- [x] public consumer52330 Native/JS/Chrome63、9新整数events/8旧polar、0errors通过，
  actualinfo/fmt5631，两private接口不变。后续area-bounds修和viewguard会由正式clean consumer复验。
- [x] Root真实UI17648终0：14项/27整数事件/0errors，desktop/375已实际截图并目视desktop；
  assets/polar.png已取该真实截图。blank候选早先落角边界的oracle问题已保before，改选明确空角；
  未改生产断言或命中政策。正式runner删不可用optional入口，中央再跑。
- [x] 中央prelude2906实际info/fmt和16JS全0。唯一新full70573终0/269.77秒：
  W/WG22678、Native22682、JS22740均通过；无意外mbti diff。
- [x] postlude86130终0：16页面Chrome204/0errors、三静态、docs56/603links、结构/diff全部通过；collector c7ac2a共23steps均0。
- [ ] 干净正式commit/push→clean包→实际publish/publicsuccess→fresh registry→GitHub四附件全下载。

精确下一动作：所有本地验收通过，正式commit/push，记录精确HEAD后freeze，执行clean build。full已通过不重跑。
通过后提交正式源并freeze HEAD，直到clean与全部网络audit结束不写tracked/不commit；实际交付后才更新发布状态。
Root当前无验证live；忽略目录M17-polar-bars保全部源/日志/失败/运行计划。不要重复已过相关检查。

## 清理与现场

按用户要求已删除D30–D54共25份tracked.tar（5304166400bytes），逐blob验证同保存Git提交后删除，
HEAD/接口/日志保留；各目录archive-cleanup.json可给Git恢复命令。未删M17或正式分发归档。
Root8765预览原session43005/PID70622；canonical JS已实际build新玫瑰图，但尚未HTTP核/刷新前台。
所有旧M16发布会话均终0，最新公开仍0.17.0；新0.18.0尚未发布。

master，SSH origin git@github.com:moonbit-community/moonplot.git。README.md symlink保持；
核心不importUI，Rabbita JS-only，pins0.16.7/XML0.5.0保持。旧完整细节留
[0.17交付历史](archive/migration-status-through-2026-10-26-m16.md)与ignored先前checkpoint。
[能力](CAPABILITIES.md) · [安装](PUBLISHING.md) · [本次范围](MILESTONE_M17.md)
