///|
/// One captured Line path and its ordered paint stages. The optional foreground
/// is resolved only after the first stroke was successfully appended.
pub struct LineDrawingContext {
  priv points : Array[@core.Point]
  priv first_style : @core.Style
  priv foreground : (() -> @core.Style raise @core.DataError)?
  priv on_complete : () -> Unit
  priv hit_points : Array[@core.Point]?
  priv discrete : DiscreteLineHitData?
}

///|
pub fn line_drawing_context(
  points : Array[@core.Point],
  first_style : @core.Style,
  on_complete : () -> Unit,
  foreground~ : (() -> @core.Style raise @core.DataError)? = None,
  hit_points~ : Array[@core.Point]? = None,
  discrete~ : DiscreteLineHitData? = None,
) -> LineDrawingContext {
  {
    points: points.copy(),
    first_style,
    foreground,
    on_complete,
    hit_points: hit_points.map(points => points.copy()),
    discrete,
  }
}

///|
/// None on a prepared context explicitly vetoes any older artist metadata.
pub fn LineDrawingContext::discrete(
  self : LineDrawingContext,
) -> DiscreteLineHitData? {
  self.discrete
}

///|
/// Captured unexpanded data points, when supplied by an owning Scene.
pub fn LineDrawingContext::hit_points(
  self : LineDrawingContext,
) -> Array[@core.Point]? {
  self.hit_points.map(points => points.copy())
}

///|
pub fn LineDrawingContext::points(
  self : LineDrawingContext,
) -> Array[@core.Point] {
  self.points.copy()
}

///|
pub fn LineDrawingContext::first_style(
  self : LineDrawingContext,
) -> @core.Style {
  self.first_style
}

///|
pub fn LineDrawingContext::resolve_foreground_style(
  self : LineDrawingContext,
) -> @core.Style? raise @core.DataError {
  match self.foreground {
    Some(resolve) => Some(resolve())
    None => None
  }
}

///|
pub fn LineDrawingContext::complete(self : LineDrawingContext) -> Unit {
  (self.on_complete)()
}
