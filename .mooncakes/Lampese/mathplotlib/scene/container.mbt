///|
/// The family of artists grouped by a plotting operation.
pub(all) enum ContainerKind {
  Generic
  Bar
  ErrorBar
  Stem
  BoxPlot
  Contour
  Quiver
  Violin
  Pie
  Stackplot
  Streamplot
}

///|
/// A stable snapshot of the artists produced by one composite plotting call.
pub struct Container {
  kind : ContainerKind
  artists : Array[Artist]
  label : String
}

///|
fn container(
  kind : ContainerKind,
  artists : Array[Artist],
  label : String,
) -> Container {
  let copied = Array(capacity=artists.length())
  for artist in artists {
    copied.push(copy_artist(artist))
  }
  { kind, artists: copied, label, }
}

///|
/// Return the container family.
pub fn Container::kind(self : Container) -> ContainerKind {
  self.kind
}

///|
/// Return copies of the grouped artists in insertion order.
pub fn Container::artists(self : Container) -> Array[Artist] {
  let result = Array(capacity=self.artists.length())
  for artist in self.artists {
    result.push(copy_artist(artist))
  }
  result
}

///|
/// Return the label supplied to the plotting operation.
pub fn Container::label(self : Container) -> String {
  self.label
}

///|
fn Axes::add_container(
  self : Axes,
  kind : ContainerKind,
  start : Int32,
  label : String,
) -> Unit {
  let artists = self.state.val.artists
  let grouped = Array(capacity=artists.length() - start)
  for index in start..<artists.length() {
    grouped.push(artists[index])
  }
  self.state.val.containers.push(container(kind, grouped, label))
}

///|
/// Return composite containers created on this axes panel.
pub fn Axes::containers(self : Axes) -> Array[Container] {
  self.state.val.containers.copy()
}

///|
/// Return composite containers created on the default axes panel.
pub fn Figure::containers(self : Figure) -> Array[Container] {
  self.axes().containers()
}
