///|
fn has_shared_axis(
  figure : @render.Figure,
  index : Int32,
  horizontal : Bool,
) -> Bool {
  let target = figure.panels()[index]
  let group = if horizontal {
    target.share_x_group()
  } else {
    target.share_y_group()
  }
  for other, panel in figure.panels() {
    if panel.polar() is Some(_) {
      continue
    }
    if other == index {
      continue
    }
    let candidate = if horizontal {
      panel.share_x_group()
    } else {
      panel.share_y_group()
    }
    if same_group(group, candidate, index, other) {
      return true
    }
  }
  false
}

///|
fn datalim_data_span(
  lower : Double,
  upper : Double,
  scale : @ticker_scale.Scale,
) -> Double {
  if lower > upper {
    -1.0 / 0.0
  } else {
    1.05 * (scale.transform(upper) - scale.transform(lower))
  }
}

///|
fn resolve_panel_scale(
  figure : @render.Figure,
  index : Int32,
) -> Scale raise @core.DataError {
  let panel = figure.panels()[index]
  if panel.polar() is Some(_) {
    validate_polar_panel(panel)
    return polar_display_scale()
  }
  if panel.adjustable() != "box" && panel.adjustable() != "datalim" {
    raise @core.DataError::InvalidReference(
      message="adjustable must be box or datalim",
    )
  }
  if panel.box_aspect() is Some(ratio) {
    if ratio <= 0.0 || ratio.is_nan() || ratio.is_inf() {
      raise @core.DataError::InvalidReference(
        message="box aspect must be finite and positive",
      )
    }
    if panel.adjustable() == "box" && panel.aspect() is None {
      raise @core.DataError::InvalidReference(
        message="automatic data aspect with box aspect requires datalim adjustment",
      )
    }
  }
  let view = compute_scale(figure, index)
  guard panel.adjustable() == "datalim" && panel.aspect() is Some(aspect) else {
    return view
  }
  let shared_x = has_shared_axis(figure, index, true)
  let shared_y = has_shared_axis(figure, index, false)
  if shared_x && shared_y {
    raise @core.DataError::InvalidReference(
      message="datalim aspect cannot adjust axes sharing both x and y",
    )
  }
  let (_, _, width, height) = box_aspect_panel_rect(figure, panel)
  if width <= 0.0 || height <= 0.0 {
    return view
  }
  let xmin = view.x_axis_scale.transform(Double::min(view.xmin, view.xmax))
  let xmax = view.x_axis_scale.transform(Double::max(view.xmin, view.xmax))
  let ymin = view.y_axis_scale.transform(Double::min(view.ymin, view.ymax))
  let ymax = view.y_axis_scale.transform(Double::max(view.ymin, view.ymax))
  let xsize = Double::max(xmax - xmin, 1.0e-30)
  let ysize = Double::max(ymax - ymin, 1.0e-30)
  let ratio = height / width / aspect
  if ratio <= 0.0 ||
    ratio.is_nan() ||
    ratio.is_inf() ||
    xsize.is_nan() ||
    xsize.is_inf() ||
    ysize.is_nan() ||
    ysize.is_inf() {
    raise @core.DataError::InvalidReference(
      message="datalim aspect cannot represent the transformed view",
    )
  }
  let y_expander = ratio * xsize / ysize - 1.0
  if y_expander.abs() < 0.005 {
    return view
  }
  let data = artist_data_scale(panel)
  let xr = datalim_data_span(data.xmin, data.xmax, view.x_axis_scale)
  let yr = datalim_data_span(data.ymin, data.ymax, view.y_axis_scale)
  let xmarg = xsize - xr
  let ymarg = ysize - yr
  let y_target = ratio * xsize
  let x_target = ysize / ratio
  let x_target_margin = x_target - xr
  let y_target_margin = y_target - yr
  let adjust_y = if shared_y {
    false
  } else if shared_x {
    true
  } else if xmarg > 0.0 && ymarg > 0.0 {
    (y_target_margin > 0.0 && y_expander < 0.0) ||
    (x_target_margin < 0.0 && y_expander > 0.0)
  } else {
    y_expander > 0.0
  }
  let (center, span, axis_scale) = if adjust_y {
    (ymin / 2.0 + ymax / 2.0, y_target, view.y_axis_scale)
  } else {
    (xmin / 2.0 + xmax / 2.0, x_target, view.x_axis_scale)
  }
  let lower = axis_scale.inverse(center - span / 2.0)
  let upper = axis_scale.inverse(center + span / 2.0)
  if span <= 0.0 ||
    !axis_scale.is_valid(lower) ||
    !axis_scale.is_valid(upper) ||
    lower == upper {
    raise @core.DataError::InvalidReference(
      message="datalim aspect produced an unrepresentable view",
    )
  }
  if adjust_y {
    if view.ymin > view.ymax {
      { ..view, ymin: upper, ymax: lower, }
    } else {
      { ..view, ymin: lower, ymax: upper, }
    }
  } else if view.xmin > view.xmax {
    { ..view, xmin: upper, xmax: lower, }
  } else {
    { ..view, xmin: lower, xmax: upper, }
  }
}

///|
/// Resolve a panel's display rectangle and data views without changing axes.
/// The result is (pixel rectangle, x limits, y limits). Invalid indices return
/// None; incompatible sharing or unrepresentable datalim views raise DataError.
///
/// ```mbt check
/// test {
///   let x = @axis.axis()
///   let y = @axis.axis()
///   try! x.set_limits(0.0, 1.0)
///   try! y.set_limits(0.0, 1.0)
///   let panel = @render.panel(
///     None,
///     [],
///     None,
///     [],
///     None,
///     x,
///     y,
///     true,
///     [],
///     [],
///     adjustable="datalim",
///   )
///   let fig = @render.figure(400, 200, 50, [panel], [], None)
///   let view = try! @svg.panel_view(fig, 0).unwrap()
///   assert_eq(view.0, (50.0, 50.0, 300.0, 100.0))
///   assert_eq(x.limits().unwrap().upper(), 1.0)
/// }
/// ```
pub fn panel_view(
  figure : @render.Figure,
  index : Int32,
) -> ((Double, Double, Double, Double), @core.Limits, @core.Limits)? raise @core.DataError {
  guard figure.panels().get(index) is Some(panel) else { return None }
  begin_tick_layout(figure)
  defer end_tick_layout(figure)
  let scale = resolve_panel_scale(figure, index)
  Some(
    (
      positioned_panel_rect(figure, panel, scale),
      @core.limits(scale.xmin, scale.xmax),
      @core.limits(scale.ymin, scale.ymax),
    ),
  )
}
