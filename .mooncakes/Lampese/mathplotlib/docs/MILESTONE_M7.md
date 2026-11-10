# M7：阶梯图、区间阶梯图与累计分布

创建日期：2026-10-25。状态：**已验收并实际发布0.8.0**。
继续补齐已有静态图的交互能力，复用现有绘制、排序与权重计算。

## 原始数据与实际几何

- [x] `step`的pre/post/mid保留原采样下标、x/y/value与plateau区间；生成的转折点不作为新增观测。
  plateau和riser复用同一原数据项，跳变归进入的新值；倒序输入不交换原索引或区间方向。
- [x] `stairs`的outline支持横竖向，保留原values下标与原edges区间；filled仅在严格单调、全有效的实际完整polygon可证明为各区间strip并集时提供区域命中。
  NaN或域外顶点被renderer删除后，不为剩余复杂面捏造矩形目标。
- [x] `ecdf`保存既有返回槽、原值与实际累计概率；覆盖weights/complementary/compress/duplicates/横竖方向。
  压缩后的返回索引不宣称为唯一原输入观测索引，不重排或重写已有统计算法。

## 共享实现与生命周期

- [x] 使用同一私有datum/path-edge载体、实际valid-run回调和Scene身份记录，避免UI反推路径。
- [x] provider在实际`points_snapshot_checked`之后验证独立expected path及当前cache；不只凭数组身份、长度或stale标记附旧语义。
  set_data、drawstyle、借用数组、remove/clear、延迟绘制和旧Drawing快照均明确处理。
- [x] 复用`HitInfo.value/interval/fraction/band`与新增Step/Stairs/Ecdf kind；不引入公共可变数组。
- [x] 可见性、面板裁剪、CSS半径、图例排除和实际绘制顺序沿用Drawing契约；不顺带重写普通Line2D或单位转换。
- [x] 先固定旧SVG控制，静态签名、返回值与SVG保持；首片不推断一般Line2D的steps drawstyle，不实现完整dash空隙几何。

## 可用性与交付

- [x] 默认及自定义Rabbita提示可读取原值、区间和概率。
- [x] 四图真实DOM示例，检查实际线段/区域、切换模式、独立显隐/更新/重挂载、CSS/letterbox和375px。
- [x] 独立专项与复审、中央组合回归、四目标全套、adapter、接口/fmt/结构通过。
- [x] clean正式包、实际Mooncakes安装、仓库外静态/DOM消费及GitHub四附件完整下载核验。

公共carrier/guard/三图由同一owner按Step→Stairs→ECDF分可验收commit，Root负责中央合入与交付。
Stem的杆/头语义已有定点设计，保留后续切片；不因已有静态入口就宣称所有图已交互对齐。
精确进度见[检查点](MIGRATION_STATUS.md)，当前发布见[安装说明](PUBLISHING.md)。

## 阶段验证

Step实现与共享底座已合入，独立专项四目标各95/95、adapter32/32；Root两组合回归四目标各2/2。
Root仓库外dirty演练已通过静态四目标与Chrome19项；这些结果限于当前Step片，不是0.8.0正式发布或后两图验收。
独立Native/JS公开消费各15组、guard各4组、14 SVG路径/字节控制通过；真实CSS端点误选已修，Native/JS各810次与各12边界控制复核通过。
Stairs已合入：Native16/16、四目标专项各80/80、adapter34/34；Root仓库外静态四目标与Chrome21通过；独立Native/JS各29组、22实际XML路径、5000个几何包含样本和两个guard均过，无阻塞。
ECDF已合入：四目标专项各117/117、adapter36/36；完整仓库外dirty演练静态四目标+Chrome23项通过，中央三组合四目标各3/3。
ECDF本体独立Native/JS各28组、26实际XML路径通过；共享重复点回归6541907修复后独立Native/JS各26组通过。
修复同时覆盖物理命中和Step横轴吸附，保持普通Line/Scatter/ErrorBar与跨artist规则；Root修后外部静态四目标/Chrome23、组合四目标各3/3重新通过。
四图DOM最后隔离构建/info与Chrome14项、0errors通过，桌面/mobile及真实PNG均已检查；源码和资产冻结。
中央85355 terminal0：info/fmt与八JS构建通过；一次最终全套Wasm/Wasm-GC/Native各22488/22488、JS22531/22531。
八个实际Chrome页面共98项通过（新离散14、分布13、网格11、统计14、图表14、提示14、双图11、资源7），均0页面错误。
三个native示例输出可解析，preview6886/gallery14246 bytes与资产逐字相同；38份Markdown/477本地链接、结构与diff通过。
Root检查真实PNG与默认/隔离JS一致，8765实际HTML/CSS/JS均HTTP200且逐字相同。0.8.0已实际发布：正式源2f7aeb77c70499979b43273d1ea8a0b0504ba040、clean包静态4目标/Chrome23、registry555源逐文件/4目标/Chrome23及GitHub四附件完整下载/tag/digest全部通过。
