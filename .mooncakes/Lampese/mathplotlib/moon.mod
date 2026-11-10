// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "Lampese/mathplotlib"

version = "0.18.0"

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/moonplot"

license = "Apache-2.0"

keywords = [ "plotting", "charts", "svg" ]

preferred_target = "wasm"

description = "A MoonBit plotting library with SVG output."

import {
  "moonbit-community/rabbita@0.16.7",
  "Milky2018/xml@0.5.0",
  "caijiewei295/tzif-engine@0.1.0",
  "moonbitlang/x@0.4.46",
}
