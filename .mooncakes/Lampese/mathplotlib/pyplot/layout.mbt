///|
/// Create and select a figure with an independent subplot grid.
pub fn subplots(
  rows~ : Int32 = 1,
  columns~ : Int32 = 1,
  width~ : Int32 = 640,
  height~ : Int32 = 480,
  hspace? : Double,
  vspace? : Double,
  share_x~ : Bool = false,
  share_y~ : Bool = false,
  width_ratios~ : Array[Double] = [],
  height_ratios~ : Array[Double] = [],
) -> (@scene.Figure, Array[@scene.Axes]) raise @gridspec.LayoutError {
  let figure = @scene.figure(width~, height~)
  let axes = figure.subplots(
    rows,
    columns,
    hspace?,
    vspace?,
    share_x~,
    share_y~,
    width_ratios~,
    height_ratios~,
  )
  current_figure.val = Some(figure)
  ignore(try! figure.sca(axes[0]))
  (figure, axes)
}

///|
/// Create and select a figure using a GridSpec's sharing constraints.
pub fn subplots_with_grid(
  grid : @gridspec.GridSpec,
  width~ : Int32 = 640,
  height~ : Int32 = 480,
) -> (@scene.Figure, Array[@scene.Axes]) raise @gridspec.LayoutError {
  let figure = @scene.figure(width~, height~)
  let axes = figure.subplots_with_grid(grid)
  current_figure.val = Some(figure)
  ignore(try! figure.sca(axes[0]))
  (figure, axes)
}

///|
/// Adjust the current figure's normalized subplot bounds and spacing.
pub fn subplots_adjust(
  left? : Double,
  bottom? : Double,
  right? : Double,
  top? : Double,
  wspace? : Double,
  hspace? : Double,
) -> Unit raise @gridspec.LayoutError {
  require_figure().subplots_adjust(
    left?,
    bottom?,
    right?,
    top?,
    wspace?,
    hspace?,
  )
}
