///|
// The original five-choice API check uses a supported-values list, not fuzzy
// suggestions. Keep its original dictionary order and Python String repr.
fn line_drawstyle_invalid_message(value : String) -> String {
  "ValueError: " +
  @ticker.python_string_repr(value) +
  " is not a valid value for drawstyle. Supported values are 'default', 'steps-mid', 'steps-pre', 'steps-post', 'steps'"
}
