///|
/// Errors raised when constructing a data series.
pub(all) suberror DataError {
  LengthMismatch(expected~ : Int32, actual~ : Int32)
  NonFiniteLimit(axis~ : String)
  InvalidErrorBar(message~ : String)
  InvalidBins
  InvalidImage(message~ : String)
  InvalidPie(message~ : String)
  InvalidBoxPlot(message~ : String)
  InvalidQuiver(message~ : String)
  InvalidViolin(message~ : String)
  InvalidContour(message~ : String)
  InvalidAnnotation(message~ : String)
  InvalidReference(message~ : String)
  InvalidStreamplot(message~ : String)
  InvalidStatistics(message~ : String)
  InvalidTicks(message~ : String)
  InvalidCollection(message~ : String)
}

///|
/// Errors raised when constructing an explicitly masked array.
pub(all) suberror MaskError {
  InvalidShape(message~ : String)
}
