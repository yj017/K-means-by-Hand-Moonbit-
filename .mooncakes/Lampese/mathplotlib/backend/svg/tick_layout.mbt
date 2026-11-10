///|
fn begin_tick_layout(figure : @render.Figure) -> Unit {
  for panel in figure.panels() {
    if panel.polar() is Some(_) {
      continue
    }
    let (_, _, width, height) = panel_rect(figure, panel)
    panel.x_axis().set_tick_layout(width, true)
    panel.y_axis().set_tick_layout(height, false)
  }
}

///|
fn end_tick_layout(figure : @render.Figure) -> Unit {
  for panel in figure.panels() {
    if panel.polar() is Some(_) {
      continue
    }
    panel.x_axis().clear_tick_layout()
    panel.y_axis().clear_tick_layout()
  }
}
