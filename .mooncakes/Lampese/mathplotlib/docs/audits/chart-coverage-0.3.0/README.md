# 0.3.0 图类调查输入与结果

2026-10-25 从实际生产 ZIP 解压并在仓库外的显式 workspace 运行。
本目录的 `main.mbt.txt` 是当次 probe 输入；`report.json` 保存四目标相同的结果。
这是代表性能力调查，结果中的 targets 计数不是将来必须保持不变的测试期望。

基线为 [GitHub v0.3.0](https://github.com/moonbit-community/moonplot/releases/tag/v0.3.0)
的 `Lampese-mathplotlib-0.3.0.zip`，源码 `2fb8bcfc54a6a071dec0a83e9ba1d054db823c4c`。
ZIP 的 SHA256 必须为
`cb737aa10e4948ae5e238493550fd0cdccdddc02d0d5bb28f1485d2f31833792`。
同版本已从 Mooncakes 实际安装并逐文件核对过。

## 复现

在新的临时目录解压 ZIP 为 `library/`，创建 `probe/`，
将本目录的 `main.mbt.txt` 复制为 `probe/main.mbt`。
文件配置如下，不能用当前工作分支替换固定的 0.3.0 库再称为同一次基线调查。

根目录 `moon.work`：

```text
members = ["library", "probe"]
```

`probe/moon.mod`：

```text
name = "moonplot-audit/probe"
version = "0.0.0"

import {
  "Lampese/mathplotlib@0.3.0",
}
```

`probe/moon.pkg`：

```text
import {
  "Lampese/mathplotlib" @plot,
}

pkgtype(kind: "executable")
```

分别运行：

```sh
moon run probe --target native > native.stdout
moon run probe --target wasm > wasm.stdout
moon run probe --target wasm-gc > wasm-gc.stdout
moon run probe --target js > js.stdout
```

输入内的断言检查同一 Figure 的 Drawing SVG 与静态 SVG 相等。
每次输出有 19 行 `AUDIT`（图名、points、targets，以 tab 分隔），随后是对应 SVG。
本轮另外用 Python `xml.etree.ElementTree` 解析每个 SVG，检查根 namespace，
并逐项比较四目标的图名、计数和 UTF-8 SVG 长度，结果相同。
这不代表对所有输入、参数、渲染外观或交互都完成验收。

当次未发生生产代码变更，未运行全项目测试。完整本地 stdout/stderr 与独立 workspace
位置记录于 `.moonagent/checkpoints/M3-chart-coverage/`；临时目录不是产品依赖。

[调查结论](../../CHART_COVERAGE.md) · [M3](../../MILESTONE_M3.md)
