# M2：可接入的浏览器交互绘图

## 当前入口：0.4.0 统一模块

用户在 v0.2.0 交付后明确要求使用 `Lampese/` 前缀发布，并将核心与组件合并。
当前方案为 **`Lampese/mathplotlib@0.4.0`**：根包用于静态出图，
`Lampese/mathplotlib/rabbita` 为同 module 的 JS 子包，别名建议 `@plot_dom`。
安装命令、迁移路径及当前发布验收见 [发布说明](PUBLISHING.md)，组件使用见
[当前指南](../rabbita/README.md)。0.3.0 新增[区域命中、横轴吸附与丰富提示](TOOLTIPS.md)。
这里不把 v0.2.0 的验证数字当作当前版本发布结果。

**以下保留 GitHub v0.2.0 的历史分发方式、路径、命令和验收结果。**
在当前分支接入请使用上方指南；已发布的 v0.2.0 tag 与附件不改写。

## v0.2.0 交付记录

版本：**0.2.0**。M2 在 M1 的静态 SVG 与已完成的 G2.1 交互上补齐多图资源隔离、
独立消费验收与版本包。保留现有模块名；不要求完整 Matplotlib API。
发布入口：[GitHub v0.2.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.2.0)。

## 固定范围

| 任务 | 交付行为 | 验收 |
| --- | --- | --- |
| 可组合 DOM | Drawing 转为公开 Rabbita SVG/Html；应用拥有状态 | 真实 SVG namespace，无 innerHTML/私有 VDOM |
| 基础交互 | 折线/散点数据点 hover、click、图例、数据更新 | 真实鼠标/键盘图例及响应式布局检查 |
| 多图生命周期 | 各图状态独立，重绘、换序、卸载/挂载 | 图例与数值不串图，不重复派发事件 |
| SVG 资源隔离 | ID 定义、本地 URL、href/xlink 链与根引用按 chart id 改写 | 两图共用 source ID 时渐变、裁剪像素各自正确 |
| 接入与发布 | 两个精简模块包、独立 source workspace、样式与许可证 | 实际 ZIP 在仓库外构建并运行浏览器消费者 |

M2 的实施与验收状态以[执行检查点](MIGRATION_STATUS.md)为准。

## 获取与运行

下载发布附件 `moonplot-v0.2.0-source.zip`，解压后进入 `moonplot-v0.2.0`：

```sh
moon run example/cmd/static --target native > chart.svg
moon build example/cmd/app --target js
python3 -m http.server 8765 --bind 127.0.0.1
```

打开 [独立交互示例](http://127.0.0.1:8765/example/)。悬停、点击点，切换图例并更新数据。
停止服务用 Ctrl+C。需要 MoonBit 工具链；native 另需 C 编译器，Python 只负责静态文件服务。

解压目录中的 `moon.work` 明确列出 `core`、`rabbita`、`example`，并非隐式使用原仓库工作区。
`example/moon.mod` 用正常版本依赖，`example/cmd/app/moon.pkg` 展示包导入。
接入自己的项目时，把两个模块放入自己的 workspace 并显式列为 members，
从 `rabbita/moonplot.css` 加载组件样式。静态核心独立使用时无需 Rabbita。

发布另附两个实际 `moon package` ZIP、`SHA256SUMS` 和 `release-manifest.json`。
manifest 记录源提交、实际包大小与摘要；source ZIP 由这两个原包解压内容和新消费者组成，
不包含开发缓存、浏览器结果或原 monorepo workspace。

**Mooncakes 尚未发布。** 已用原模块名做服务端权限预检，两者均返回 403 User mismatch；
当前账号无 `mathplotlib` / `moonbit-community` 命名空间发布权限。
因此当前交付渠道是 GitHub 源码版本包，不能宣称 registry-only `moon add` 已可用。
没有为绕过权限修改模块导入名。

## 资源隔离契约

每个图使用不同、非空的 `id`，根 DOM ID 仍为 `id + "-svg"`；应用也应为这些派生根 ID 保留页面唯一性。
adapter 解析后先收集源 ID，再按稳定命名空间改写定义和本地引用，
包括 presentation attributes、inline CSS `url(...)`、quoted/escaped URL、UTF-8 percent fragment、
`href` / `xlink:href` 渐变链和源根 ID 别名。普通颜色、外部/data URL 不改。
Drawing、原始 SVG、图形坐标与 hit 数据保持原样；静态输出不受影响。

空/重复源 ID、未知本地目标、歧义 percent fragment、冲突 href/xlink 会明确报错。
只使用公开 Rabbita 0.16.7 API；其 SVG Attrs 没有公开 ARIA setters，
所以 SVG 的 `aria-labelledby` / `aria-describedby` 仍明确不支持。
HTML 图例按钮已有 aria 属性，不把内部引用转换误记为 SVG 无障碍支持。

## 可复现验收

| 本轮检查 | 结果 |
| --- | --- |
| 核心 check 四目标 / info / fmt | 通过；7 条既有 Ref 警告，0 error；既有公开 mbti 不变 |
| 相关核心回归 | wasm / wasm-gc / js / native 各 370/370 |
| adapter check / info / fmt / 两示例 build | 通过；JS 单测 14/14 |
| 原双图应用 | Chrome 155，11 项交互/布局通过，0 页面错误 |
| 资源冲突专项 | Chrome 155，7 组通过；同页渐变/clip 像素正确 |
| 实际 ZIP 的仓库外消费者 | 静态四目标运行并解析 SVG；JS build、浏览器 5 项通过，0 页面错误 |
| 核心发布预检 | 精简包的解压 check 已通过；随后服务端 403 权限拒绝 |

本轮没有重新运行或冒称历史两万余项全套测试。改动限定在 adapter 与发布接入，
相关核心回归、独立消费及真实浏览器为本次验收依据。

```sh
# 根目录
moon check --target all
moon test drawing backend/svg scene/drawing_wbtest.mbt \
  scene/figure_test.mbt scene/category_test.mbt scene/statistics_test.mbt \
  scene/image_test.mbt scene/date_test.mbt scene/autoscale_state_wbtest.mbt \
  scene/grid_axis_regression_test.mbt scene/legend_position_test.mbt \
  scene/legend_position_wbtest.mbt tests/api/readme_examples_test.mbt \
  tests/api/usability_test.mbt tests/api/drawing_export_test.mbt --target all

cd adapters/rabbita
moon check --target js
moon test . --target js
moon build cmd/demo cmd/resources --target js
cd ../..

PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node adapters/rabbita/browser_test.cjs
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright node adapters/rabbita/resource_browser_test.cjs
# 先提交发布源；工具会拒绝未提交的正式发布包。
PLAYWRIGHT_MODULE=/path/to/node_modules/playwright python3 tools/build_release.py
```

资源回归有旧版真实失败依据：相同文档中 8 个重复 ID，蓝图误用红图渐变且裁剪反向。
修复后的七组浏览器检查直接检查同页截图像素、computed URL 目标、href 链、根别名、独立事件、
重绘后的边界、图序交换、三次重挂载；不以单张 SVG 独立栅格化替代多图验证。

打包工具会先打核心包，再在仓库外用该核心 ZIP 打适配器，避免根 `.moonignore` 排除嵌套
adapter 时影响它自己的归档。两个包均排除测试/缓存/原工作区；核心保留 ticker pre-build 必需的 packed 输入。
仓库里的原始测试和参考数据均保留。

详细本地证据在忽略目录 `.moonagent/checkpoints/M2/`；命令、fixture 和 runner 随 Git 提交，
发布包的外部消费由 `tools/build_release.py` 与 `tools/verify_release_consumer.cjs` 复现。
原 G2.1 行为与数据契约见 [DOM 说明](RABBITA_DOM.md)。

## 后续范围

M2 不包含缩放/平移、框选、触摸手势、键盘点导航、全部图形轮廓命中或大数据空间索引。
命中仍为 Line/Scatter/PathCollection 的当前帧数值数据点锚点；应用在数据替换/重排后刷新选择。
SVG 根上的任意 CSS transform、border/padding 与其他 preserveAspectRatio 仍未覆盖。
这些能力按具体场景后续迭代，不阻碍本次交互绘图可用版交付。
