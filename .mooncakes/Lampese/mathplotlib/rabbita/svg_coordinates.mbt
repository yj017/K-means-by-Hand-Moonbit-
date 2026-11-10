///|
// Private JavaScript result. No DOMMatrix API or mutable result is exported.
priv type SvgClientMapping

///|
extern "js" fn svg_client_mapping_native(
  root : @dom.Element,
  client_x : Double,
  client_y : Double,
) -> SvgClientMapping =
  #| (root, clientX, clientY) => {
  #|   const absent = { x: NaN, y: NaN, scale: NaN };
  #|   if (!Number.isFinite(clientX) || !Number.isFinite(clientY) || typeof root.getScreenCTM !== 'function') return absent;
  #|   const m = root.getScreenCTM();
  #|   if (!m || m.is2D === false) return absent;
  #|   const { a, b, c, d, e, f } = m;
  #|   if (![a, b, c, d, e, f].every(Number.isFinite)) return absent;
  #|   const sx = Math.hypot(a, b), sy = Math.hypot(c, d), det = a * d - b * c;
  #|   if (!Number.isFinite(sx) || !Number.isFinite(sy) || sx <= 0 || sy <= 0 || !Number.isFinite(det) || det === 0) return absent;
  #|   // A scalar CSS radius is valid only for a uniform, orthogonal mapping.
  #|   // This allowance is relative binary64 arithmetic noise, never pixels.
  #|   const roundoff = 64 * Number.EPSILON;
  #|   if (Math.abs(sx - sy) > roundoff * Math.max(sx, sy) || Math.abs((a / sx) * (c / sy) + (b / sx) * (d / sy)) > roundoff) return absent;
  #|   const px = clientX - e, py = clientY - f;
  #|   const x = (d * px - c * py) / det, y = (-b * px + a * py) / det;
  #|   return Number.isFinite(x) && Number.isFinite(y) ? { x, y, scale: sx } : absent;
  #| }

///|
extern "js" fn SvgClientMapping::x(self : SvgClientMapping) -> Double =
  #| mapping => mapping.x

///|
extern "js" fn SvgClientMapping::y(self : SvgClientMapping) -> Double =
  #| mapping => mapping.y

///|
extern "js" fn SvgClientMapping::scale(self : SvgClientMapping) -> Double =
  #| mapping => mapping.scale

///|
// The actual SVG CTM includes its own border/padding, meet letterboxing and
// ancestor placement. Intrinsic Figure bounds reject padding and letterbox.
fn svg_client_coordinates(
  drawing : @drawing.Drawing,
  root : @dom.Element,
  client_x : Double,
  client_y : Double,
) -> (Double, Double, Double)? {
  let mapping = svg_client_mapping_native(root, client_x, client_y)
  let (x, y, scale) = (mapping.x(), mapping.y(), mapping.scale())
  if x.is_nan() ||
    x.is_inf() ||
    y.is_nan() ||
    y.is_inf() ||
    scale.is_nan() ||
    scale.is_inf() ||
    scale <= 0.0 ||
    drawing.width() <= 0 ||
    drawing.height() <= 0 ||
    x < 0.0 ||
    y < 0.0 ||
    x > drawing.width().to_double() ||
    y > drawing.height().to_double() {
    None
  } else {
    Some((x, y, scale))
  }
}
