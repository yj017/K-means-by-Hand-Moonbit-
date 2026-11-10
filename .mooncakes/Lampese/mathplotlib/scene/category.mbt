///|
fn category_x_points(
  axes : Axes,
  categories : Array[String],
  values : Array[Double],
) -> Array[@core.Point] raise @core.DataError {
  if categories.length() != values.length() {
    raise @core.DataError::LengthMismatch(
      expected=categories.length(),
      actual=values.length(),
    )
  }
  if !axes.state.val.x_axis.have_units() {
    ignore(axes.state.val.x_axis.update_category_units(categories))
  }
  let positions = axes.state.val.x_axis.convert_category_units(categories)
  let points = Array(capacity=values.length())
  for i in 0..<values.length() {
    points.push(@core.point(positions[i], values[i]))
  }
  points
}

///|
fn category_y_points(
  axes : Axes,
  values : Array[Double],
  categories : Array[String],
) -> Array[@core.Point] raise @core.DataError {
  if values.length() != categories.length() {
    raise @core.DataError::LengthMismatch(
      expected=values.length(),
      actual=categories.length(),
    )
  }
  if !axes.state.val.y_axis.have_units() {
    ignore(axes.state.val.y_axis.update_category_units(categories))
  }
  let positions = axes.state.val.y_axis.convert_category_units(categories)
  let points = Array(capacity=values.length())
  for i in 0..<values.length() {
    points.push(@core.point(values[i], positions[i]))
  }
  points
}

///|
/// Configure string categories on the x axis.
pub fn Axes::set_x_categories(
  self : Axes,
  labels : Array[String],
) -> Unit raise @core.DataError {
  let units = @axis.CategoryUnits::new(labels)
  for state in self.x_group_states() {
    state.val.x_axis.set_category_units(units)
  }
}

///|
/// Configure string categories on the default x axis.
pub fn Figure::set_x_categories(
  self : Figure,
  labels : Array[String],
) -> Unit raise @core.DataError {
  self.axes().set_x_categories(labels)
}

///|
/// Configure string categories on the y axis.
pub fn Axes::set_y_categories(
  self : Axes,
  labels : Array[String],
) -> Unit raise @core.DataError {
  let units = @axis.CategoryUnits::new(labels)
  for state in self.y_group_states() {
    state.val.y_axis.set_category_units(units)
  }
}

///|
/// Configure string categories on the default y axis.
pub fn Figure::set_y_categories(
  self : Figure,
  labels : Array[String],
) -> Unit raise @core.DataError {
  self.axes().set_y_categories(labels)
}

///|
/// Add a line whose x coordinates are string categories.
pub fn Axes::plot_category(
  self : Axes,
  categories : Array[String],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.attach_line_with_originals(
    category_x_points(self, categories, values),
    LineData::Category(categories),
    LineData::Numeric(values),
    color~,
    label~,
  )
}

///|
/// Add scatter points whose x coordinates are string categories.
pub fn Axes::scatter_category(
  self : Axes,
  categories : Array[String],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.scatter(category_x_points(self, categories, values), color~, label~)
}

///|
/// Add bars whose x coordinates are string categories.
pub fn Axes::bar_category(
  self : Axes,
  categories : Array[String],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.bar(category_x_points(self, categories, values), color~, label~)
}

///|
/// Add a line whose y coordinates are string categories.
pub fn Axes::plot_category_y(
  self : Axes,
  values : Array[Double],
  categories : Array[String],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.attach_line_with_originals(
    category_y_points(self, values, categories),
    LineData::Numeric(values),
    LineData::Category(categories),
    color~,
    label~,
  )
}

///|
/// Add scatter points whose y coordinates are string categories.
pub fn Axes::scatter_category_y(
  self : Axes,
  values : Array[Double],
  categories : Array[String],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.scatter(category_y_points(self, values, categories), color~, label~)
}

///|
/// Add bars whose y coordinates are string categories.
pub fn Axes::bar_category_y(
  self : Axes,
  values : Array[Double],
  categories : Array[String],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  let points = category_y_points(self, values, categories)
  let resolved_color = self.resolve_color(color)
  let start = self.state.val.artists.length()
  self.push_artist(
    Artist::BarH(
      points,
      @core.style(resolved_color, width=0.0, fill=resolved_color),
    ),
  )
  self.add_auto_legend(label, resolved_color, LegendKind::Patch)
  self.add_container(ContainerKind::Bar, start, label)
}

///|
/// Add a line whose x coordinates are string categories to the default axes.
pub fn Figure::plot_category(
  self : Figure,
  categories : Array[String],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().plot_category(categories, values, color~, label~)
}

///|
/// Add a line whose y coordinates are string categories to the default axes.
pub fn Figure::plot_category_y(
  self : Figure,
  values : Array[Double],
  categories : Array[String],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().plot_category_y(values, categories, color~, label~)
}

///|
/// Add scatter points whose x coordinates are string categories to the default axes.
pub fn Figure::scatter_category(
  self : Figure,
  categories : Array[String],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().scatter_category(categories, values, color~, label~)
}

///|
/// Add scatter points whose y coordinates are string categories to the default axes.
pub fn Figure::scatter_category_y(
  self : Figure,
  values : Array[Double],
  categories : Array[String],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().scatter_category_y(values, categories, color~, label~)
}

///|
/// Add bars whose x coordinates are string categories to the default axes.
pub fn Figure::bar_category(
  self : Figure,
  categories : Array[String],
  values : Array[Double],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().bar_category(categories, values, color~, label~)
}

///|
/// Add horizontal bars whose y coordinates are string categories to the default axes.
pub fn Figure::bar_category_y(
  self : Figure,
  values : Array[Double],
  categories : Array[String],
  color~ : String = "",
  label~ : String = "",
) -> Unit raise @core.DataError {
  self.axes().bar_category_y(values, categories, color~, label~)
}
