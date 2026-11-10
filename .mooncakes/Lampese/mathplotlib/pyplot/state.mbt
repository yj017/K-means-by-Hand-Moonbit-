///|
let current_figure : @ref.Ref[@scene.Figure?] = @ref.new(None)

///|
fn require_figure() -> @scene.Figure {
  match current_figure.val {
    Some(figure) => figure
    None => {
      let figure = @scene.figure()
      current_figure.val = Some(figure)
      figure
    }
  }
}

///|
fn require_axes() -> @scene.Axes {
  require_figure().gca()
}

///|
/// Create and select the current figure.
pub fn figure(width~ : Int32 = 640, height~ : Int32 = 480) -> @scene.Figure {
  let figure = @scene.figure(width~, height~)
  current_figure.val = Some(figure)
  figure
}

///|
/// Return the current figure, creating a default one when needed.
pub fn gcf() -> @scene.Figure {
  require_figure()
}

///|
/// Return the current axes, creating a default one when needed.
pub fn gca() -> @scene.Axes {
  require_axes()
}

///|
/// Add and select an axes panel in the current figure.
/// With no coordinates, create a 1-by-1 subplot using the figure's subplot
/// bounds. Supplying any coordinate creates a fixed manual rectangle instead;
/// omitted coordinates then use (0.125, 0.11, 0.775, 0.77).
///
/// ```mbt check
/// test {
///   let fig = @pyplot.figure(width=400, height=300)
///   let panel = try! @pyplot.axes(left=0.1, bottom=0.2, width=0.5, height=0.4)
///   @pyplot.title("inset")
///   assert_eq(panel.title(), Some("inset"))
///   assert_eq(fig.axes_list().length(), 1)
///   @pyplot.close()
/// }
/// ```
pub fn axes(
  left? : Double,
  bottom? : Double,
  width? : Double,
  height? : Double,
) -> @scene.Axes raise @gridspec.LayoutError {
  let figure = require_figure()
  let axes = match (left, bottom, width, height) {
    (None, None, None, None) =>
      figure.add_subplot(@gridspec.gridspec(1, 1).cell_spec(0, 0))
    _ =>
      figure.add_axes(
        left.unwrap_or(0.125),
        bottom.unwrap_or(0.11),
        width.unwrap_or(0.775),
        height.unwrap_or(0.77),
      )
  }
  axes
}

///|
/// Select an attached axes panel and its owning figure for subsequent calls.
/// Selection preserves the figure's axes creation and drawing order. A
/// detached handle raises InvalidReference and leaves the selection intact.
///
/// ```mbt check
/// test {
///   let first = @pyplot.figure(width=400, height=300)
///   let panel = first.axes()
///   ignore(@pyplot.figure())
///   try! @pyplot.sca(panel)
///   @pyplot.title("selected")
///   assert_eq(panel.title(), Some("selected"))
///   assert_eq(@pyplot.gcf().width(), 400)
///   @pyplot.close()
/// }
/// ```
pub fn sca(axes : @scene.Axes) -> Unit raise @core.DataError {
  ignore(axes.figure().sca(axes))
  current_figure.val = Some(axes.figure())
}

///|
/// Remove an axes panel, defaulting to the current panel.
/// An explicit panel is removed from its own Figure without switching the
/// current Figure. Detached handles raise InvalidReference.
///
/// ```mbt check
/// test {
///   let fig = @pyplot.figure()
///   let ax = @pyplot.gca()
///   try! @pyplot.delaxes()
///   assert_eq(fig.axes_list().length(), 0)
///   assert_true(!ax.is_attached())
///   assert_true(@pyplot.gca().is_attached())
///   @pyplot.close()
/// }
/// ```
pub fn delaxes(ax? : @scene.Axes) -> Unit raise @core.DataError {
  ax.unwrap_or_else(() => require_axes()).remove()
}

///|
/// Clear the current figure while retaining its size.
pub fn clf() -> Unit {
  let old = require_figure()
  current_figure.val = Some(
    @scene.figure(width=old.width(), height=old.height()),
  )
}

///|
/// Clear the current axes while retaining its figure and subplot position.
pub fn cla() -> Unit {
  require_axes().clear()
}

///|
/// Clear the current figure.
pub fn clear() -> Unit {
  clf()
}

///|
/// Restore global plotting defaults for subsequently created axes.
pub fn rcdefaults() -> Unit {
  @config.reset()
}

///|
/// Replace the property color cycle for subsequently created axes.
pub fn set_prop_cycle(colors : Array[String]) -> Unit raise @core.DataError {
  @config.set_color_cycle(colors)
}

///|
/// Close the current figure.
pub fn close() -> Unit {
  current_figure.val = None
}
