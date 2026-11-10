# M12：填色等值区、孔洞与区间提示

创建日期：2026-10-25。状态：**已验收并实际发布0.13.0**。当前正式版本0.13.0。
从正式源`ae1ce6b4c45d17fd2c1fbee388525f5c7f713307`继续，补已有`contourf`、`tricontourf`及三角网格wrapper；不重新计算标量场或复制全部Matplotlib参数。

## 能力合同

- [x] 新增`HitKind::ContourF`及`HitShape::FilledRegion(FilledRegion)`。区域值私有保存环和填充规则，构造及getter深复制；Drawing及旧帧不能泄漏可变别名。
- [x] 单Polygon沿真实SVG的nonzero规则，多环Compound沿真实evenodd规则；一次捕获全部实际写出的环，孔洞和分离岛屿之间的空白保持正确。
- [x] `interval`为原标量clipper实际使用的有限上下界，`value`为代表值，`series`为原call名称。保留旧有限layer值；仅有限端点相加溢出时安全平均，不改原ContourSet getter算术，不伪装鼠标处的场值。
- [x] `point_index`为原逻辑band/color槽，保留空band与extension槽洞；不等于`layers()`去空去重后的索引或`segments()`展平的环索引。`artist_index`为当前实际Polygon/Compound。
- [x] 两mode只命中plot内真实填色区域；不把bbox、每个环分别填面、孔洞或XNearest整面板当作命中。旧SVG有可见margin填色，margin保持静态，不虚构axes clip资源或改静态裁剪。
- [x] 有可见实际非零边时，数据锚点取该边clip前安全中点，屏幕锚点取可见片段中点；无边穿过plot时，一次中心containment证明覆盖后，屏幕取plot中心、数据取首实际非零边中点。二者描述区域几何，不冒充原样本或逆尺度配对坐标。
- [x] 默认提示显示Range和Representative，不展示几何XY；保留自定义日期、单位和中文格式入口，不增加ContourFInfo或伪Area BandInfo。
- [x] 保原签名、levels/layers/paths/mask/corner_mask/locator、Container、颜色、静态legend与正常同target SVG。额外仅修空/无band调用串改前一series，复用条件名称记录。
- [x] 身份/内容/prepared context不匹配保守静态，无generic Polygon回退或拆线后归属复活；维护remove/clear/image/inline及已交付Contour/Barbs语义。
- [x] 额外快照、guard、捕获与cursor准备为O(总生成几何＋artists)，pointer查询为相关边数；Region有效性预验证缓存，不每次查询再全量验证或每边复制整区/网格。

## 验收与交付

- [x] 原逻辑槽、有限under/normal/over范围、empty extensions、同值不同band、自动levels及direct/wrapper。
- [x] 实际nonzero/evenodd、多环孔洞、分离岛屿与bbox空隙、孔洞透选更早填色、实际paint顺序和两mode。
- [x] filter后实际写出几何、mask/非线性轴/反轴、透明/零宽填色、plot与margin边界及两类锚点。
- [x] Region输入和两层getter别名、公开Drawing构造、旧帧、identity/content失配、生命周期与有界多边压力。
- [x] 精确0.12源的同target旧SVG、独立Native/JS实际XML及必要四目标/adapter。
- [x] 真实双卡DOM，默认/中文区间代表值、更新/图例/重挂载、CSS与375px；Chrome以实际Path/Polygon的`isPointInFill`及plot边界作独立oracle。
- [x] 中央info/fmt/结构/一次全套、13页面Chrome162项与三静态SVG。
- [x] clean包、实际Mooncakes/registry与GitHub四附件完整下载。

## 实际验收记录

- 最终producer `f91dab853b214da3b5b5a2c5d45b0a729d4fd86a` 的31文件含18production/3interfaces与Root逐字相同；生产自guard修复 `14a09c2` 不变。受影响四目标各184/184、adapter46/46、8份同target旧SVG通过。
- mixed collinear ring、极远坐标BBox与ContourF metadata跨kind三个真实反例均保留before并修复；最后类型域gate只允许实际Polygon/Compound，保provider completion与静态输出。独立Native/JS各3组delta通过，原blocker解除。
- 独立c02证据：Native/JS各9 public、各5 Scene白盒，18份实际XML/18份同target正式0.12 SVG逐字一致；每target12个实际region、432个独立XML winding/clip查询一致，最大坐标差2.842170943040401e-14。加14a唯一Panel delta后无剩余blocker。
- 真实双卡Chrome14项、24整数事件、0pageerrors；原槽1/2/3、孔洞透选、分岛gap、737真实mask前样本、图例/重挂载/CSS/375px通过。最终中央截图与assets/filled-contours.png逐字相同，图片已目视。
- 外部consumer Native/JS、实际info/fmt及Chrome41项/10个填色整数事件/0pageerrors通过，两份实际mbti无变化。
- Root prelude16307及postlude47933均terminal0；唯一full30284 terminal0/268.45s：W/WG22589、JS22642、Native22591。13页面Chrome162项/0errors、三静态SVG（preview/gallery逐字）、48文档538链接/结构/diff通过，无额外mbti；未重复全套。

正式源87a3280f31fb3ba043da415f89eab6ad5a8ef59e/push68683；clean20806、actualpublish46591/200、publicAPI64558 buildsuccess/haspackage/notyanked/checksum匹配、全新registry60742四静态/Chrome41与590安装源逐一匹配均通过。GHcreate21562及整下载72398核验四附件bytes/digest/size/tag通过；最终audit2026-10-25T14:19:05.947223Z，Root全程HEAD固定87a且gitclean、无tracked写/commit，然后解除freeze。

[GitHub v0.13.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.13.0)。producer负责core/IR/Scene/backend/Drawing/tooltip、own tests与专项指南；Root负责组合、consumer、UI、版本与交付。

[执行检查点](MIGRATION_STATUS.md) · [能力](CAPABILITIES.md) · [专项指南](CONTOURF_INTERACTION.md) · [安装与发布](PUBLISHING.md)
