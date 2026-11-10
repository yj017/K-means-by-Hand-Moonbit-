///|
// Do not statically import node:fs into browser bundles. Node's builtin-module
// lookup is guarded; embedded hosts without files supply a parser context.
extern "js" fn read_zone_bytes(path : String) -> Bytes =
  #| function(path) {
  #|   const p = globalThis.process;
  #|   if (!p || typeof p.getBuiltinModule !== "function") return new Uint8Array(0);
  #|   try { return p.getBuiltinModule("node:fs").readFileSync(path); }
  #|   catch (_) { return new Uint8Array(0); }
  #| }

///|
pub fn read_zone_file(path : String) -> Bytes? {
  let bytes = read_zone_bytes(path)
  if bytes.is_empty() {
    None
  } else {
    Some(bytes)
  }
}

///|
// moon.pkg cannot conditionally import a package yet. Retain the native/Wasm
// dependency in type checking without invoking it or linking its JS FS calls.
#warnings("-unused_value")
fn native_dependency() -> Unit {
  ignore(@fs.path_exists)
}
