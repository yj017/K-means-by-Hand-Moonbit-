///|
/// Legend placement is a public value shared with render backends.
pub using @core {type LegendPosition}

///|
/// The visual sample used by one legend entry.
pub(all) enum LegendKind {
  Line
  Marker
  Patch
}

///|
/// A labeled visual entry displayed inside an axes legend.
pub struct LegendEntry {
  label : String
  color : String
  kind : LegendKind
}

///|
/// Construct a legend entry with a line sample by default.
pub fn legend_entry(
  label : String,
  color~ : String = "#1f77b4",
  kind~ : LegendKind = LegendKind::Line,
) -> LegendEntry {
  { label, color, kind, }
}

///|
pub fn LegendEntry::label(self : LegendEntry) -> String {
  self.label
}

///|
pub fn LegendEntry::color(self : LegendEntry) -> String {
  self.color
}

///|
pub fn LegendEntry::kind(self : LegendEntry) -> LegendKind {
  self.kind
}

///|
/// Replace this panel's legend entries.
pub fn Axes::set_legend(self : Axes, entries : Array[LegendEntry]) -> Unit {
  self.state.val.legend = entries.copy()
  self.state.val.explicit_legend = true
}

///|
/// Alias for `set_legend` matching the pyplot vocabulary.
pub fn Axes::legend(self : Axes, entries : Array[LegendEntry]) -> Unit {
  self.set_legend(entries)
}

///|
/// Anchor this axes' automatic or explicit legend to a panel corner.
pub fn Axes::set_legend_position(
  self : Axes,
  position : LegendPosition,
) -> Unit {
  self.state.val.legend_position = position
}

///|
/// Return this axes' legend anchor, initially UpperRight.
pub fn Axes::legend_position(self : Axes) -> LegendPosition {
  self.state.val.legend_position
}

///|
/// Remove this panel's legend.
pub fn Axes::clear_legend(self : Axes) -> Unit {
  self.state.val.legend.clear()
  self.state.val.explicit_legend = false
}

///|
fn has_legend_label(entries : Array[LegendEntry], label : String) -> Bool {
  for entry in entries {
    if entry.label() == label {
      return true
    }
  }
  false
}

///|
/// Add one automatic legend entry, retaining the first occurrence of a label.
fn Axes::add_auto_legend(
  self : Axes,
  label : String,
  color : String,
  kind : LegendKind,
  record_series~ : Bool = true,
) -> Unit {
  if record_series {
    self.record_hit_series(label)
  }
  if label == "" || has_legend_label(self.state.val.auto_legend, label) {
    return
  }
  self.state.val.auto_legend.push(legend_entry(label, color~, kind~))
}

///|
/// Return the effective legend, with explicit entries taking precedence.
fn AxesData::legend_entries(self : AxesData) -> Array[LegendEntry] {
  if self.explicit_legend {
    self.legend.copy()
  } else {
    self.auto_legend.copy()
  }
}

///|
/// Return the legend entries that would be rendered for this axes.
pub fn Axes::legend_entries(self : Axes) -> Array[LegendEntry] {
  self.state.val.legend_entries()
}

///|
/// Return the legend entries that would be rendered for the default axes.
pub fn Figure::legend_entries(self : Figure) -> Array[LegendEntry] {
  self.axes().legend_entries()
}

///|
/// Set legend entries on the default axes.
pub fn Figure::set_legend(self : Figure, entries : Array[LegendEntry]) -> Unit {
  self.axes().set_legend(entries)
}

///|
/// Set legend entries on the default axes.
pub fn Figure::legend(self : Figure, entries : Array[LegendEntry]) -> Unit {
  self.set_legend(entries)
}

///|
/// Set the legend anchor on the default axes.
pub fn Figure::set_legend_position(
  self : Figure,
  position : LegendPosition,
) -> Unit {
  self.axes().set_legend_position(position)
}

///|
/// Return the legend anchor on the default axes.
pub fn Figure::legend_position(self : Figure) -> LegendPosition {
  self.axes().legend_position()
}
