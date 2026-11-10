///|
/// Numeric locale conventions for formatter strings, independent of rc defaults.
pub struct NumericLocale {
  priv decimal_point : String
  priv thousands_sep : String
  priv grouping : Array[Int32]
}

///|
/// Retain the grouping array; zero repeats a group and 127 ends grouping.
pub fn NumericLocale::new(
  decimal_point~ : String = ".",
  thousands_sep~ : String = "",
  grouping~ : Array[Int32] = [],
) -> NumericLocale {
  { decimal_point, thousands_sep, grouping, }
}

///|
pub fn NumericLocale::decimal_point(self : NumericLocale) -> String {
  self.decimal_point
}

///|
pub fn NumericLocale::thousands_sep(self : NumericLocale) -> String {
  self.thousands_sep
}

///|
pub fn NumericLocale::grouping(self : NumericLocale) -> Array[Int32] {
  self.grouping
}

///|
let current_numeric_locale : @ref.Ref[NumericLocale] = @ref.Ref(
  NumericLocale::new(),
)

///|
pub fn numeric_locale() -> NumericLocale {
  current_numeric_locale.val
}

///|
pub fn set_numeric_locale(value : NumericLocale) -> Unit {
  current_numeric_locale.val = value
}
