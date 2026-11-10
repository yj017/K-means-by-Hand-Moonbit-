///|
/// An ordered converter from string categories to numeric axis positions.
///
/// Categories are assigned positions in first-seen order. Repeated labels
/// reuse the position that was assigned to their first occurrence.
pub struct CategoryAxis {
  labels : Array[String]
}

///|
/// Create an empty category converter.
pub fn category() -> CategoryAxis {
  { labels: [], }
}

///|
fn find_label(labels : Array[String], label : String) -> Int32? {
  for i in 0..<labels.length() {
    if labels[i] == label {
      return Some(i)
    }
  }
  None
}

///|
/// Add labels to this converter and return the extended converter.
pub fn CategoryAxis::with_labels(
  self : CategoryAxis,
  labels : Array[String],
) -> CategoryAxis {
  let (_, result) = self.encode(labels)
  result
}

///|
/// Convert string values to stable numeric positions.
/// Empty strings are valid categories; the `String` element type rejects
/// non-string values before this function is called.
pub fn CategoryAxis::encode(
  self : CategoryAxis,
  values : Array[String],
) -> (Array[Double], CategoryAxis) {
  let next : CategoryAxis = { labels: self.labels.copy(), }
  let positions = Array(capacity=values.length())
  for value in values {
    let index = match find_label(next.labels, value) {
      Some(index) => index
      None => {
        let index = next.labels.length()
        next.labels.push(value)
        index
      }
    }
    positions.push(Double::from_int(index))
  }
  (positions, next)
}

///|
/// Return the numeric position for each known category.
pub fn CategoryAxis::tick_positions(self : CategoryAxis) -> Array[Double] {
  let result = Array(capacity=self.labels.length())
  for i in 0..<self.labels.length() {
    result.push(Double::from_int(i))
  }
  result
}

///|
/// Return category labels in their stable first-seen order.
pub fn CategoryAxis::tick_labels(self : CategoryAxis) -> Array[String] {
  self.labels.copy()
}

///|
/// Return all known labels in their stable first-seen order.
pub fn CategoryAxis::labels(self : CategoryAxis) -> Array[String] {
  self.labels.copy()
}

///|
/// Return the number of known categories.
pub fn CategoryAxis::length(self : CategoryAxis) -> Int32 {
  self.labels.length()
}
