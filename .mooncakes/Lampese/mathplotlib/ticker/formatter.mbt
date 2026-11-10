///|
/// Numeric tick formatter modeled after the public matplotlib.ticker
/// formatter family.  The formatter is immutable; array-valued formatters
/// copy their labels when constructed and when queried.
pub(all) enum Formatter {
  Scalar(
    use_offset~ : Bool,
    use_math_text~ : Bool,
    power_min~ : Int32,
    power_max~ : Int32
  )
  Fixed(Array[String])
  Index(Array[String])
  Format(String)
  StrMethod(String)
  Eng(unit~ : String, places~ : Int32, sep~ : String)
  Percent(xmax~ : Double, decimals~ : Int32, symbol~ : String)
  Log(base~ : Double, label_only_base~ : Bool)
  Null
  Func((Double) -> String)
}

///|
/// Construct a scalar formatter with Matplotlib-like power limits.
pub fn scalar_formatter(
  use_offset~ : Bool = true,
  use_math_text~ : Bool = false,
  power_min~ : Int32 = -5,
  power_max~ : Int32 = 6,
) -> Formatter raise @core.DataError {
  if power_min > power_max {
    raise @core.DataError::InvalidTicks(
      message="scalar formatter power_min must not exceed power_max",
    )
  }
  Formatter::Scalar(use_offset~, use_math_text~, power_min~, power_max~)
}

///|
/// Construct a formatter that returns labels by tick position.
pub fn fixed_formatter(labels : Array[String]) -> Formatter {
  Formatter::Fixed(labels.copy())
}

///|
/// Construct a formatter that treats values as integer label indices.
pub fn index_formatter(labels : Array[String]) -> Formatter {
  Formatter::Index(labels.copy())
}

///|
/// Construct a printf-style numeric formatter.
///
/// The supported conversions are `%g`, `%f`, `%e`, `%d`, and `%%`.  A
/// precision such as `%.2f` is accepted for `%f` and `%e`; unsupported
/// conversions are preserved literally so a label is never silently lost.
pub fn format_str_formatter(format : String) -> Formatter {
  Formatter::Format(format)
}

///|
/// Construct a Python `str.format`-style numeric formatter.
pub fn str_method_formatter(format : String) -> Formatter {
  Formatter::StrMethod(format)
}

///|
/// Construct an engineering-notation formatter.
pub fn eng_formatter(
  unit~ : String = "",
  places~ : Int32 = -1,
  sep~ : String = " ",
) -> Formatter raise @core.DataError {
  if places < -1 || places > 15 {
    raise @core.DataError::InvalidTicks(
      message="engineering formatter places must be -1 or in 0..15",
    )
  }
  Formatter::Eng(unit~, places~, sep~)
}

///|
/// Construct a percentage formatter. `decimals=-1` selects precision from the
/// displayed tick range, matching Matplotlib's automatic percentage labels.
pub fn percent_formatter(
  xmax~ : Double = 100.0,
  decimals~ : Int32 = -1,
  symbol~ : String = "%",
) -> Formatter raise @core.DataError {
  if xmax.is_nan() || xmax.is_inf() || xmax == 0.0 {
    raise @core.DataError::InvalidTicks(
      message="percent formatter xmax must be finite and non-zero",
    )
  }
  if decimals < -1 || decimals > 15 {
    raise @core.DataError::InvalidTicks(
      message="percent formatter decimals must be -1 or in 0..15",
    )
  }
  Formatter::Percent(xmax~, decimals~, symbol~)
}

///|
/// Construct a logarithmic formatter.
pub fn log_formatter(
  base~ : Double = 10.0,
  label_only_base~ : Bool = false,
) -> Formatter raise @core.DataError {
  if base.is_nan() || base.is_inf() || base <= 1.0 {
    raise @core.DataError::InvalidTicks(
      message="log formatter base must be finite and greater than one",
    )
  }
  Formatter::Log(base~, label_only_base~)
}

///|
/// Construct a formatter that suppresses all labels.
pub fn null_formatter() -> Formatter {
  Formatter::Null
}

///|
/// Construct a formatter backed by a user function.
pub fn func_formatter(function : (Double) -> String) -> Formatter {
  Formatter::Func(function)
}

///|
/// Copy a formatter without sharing mutable label storage.
pub fn Formatter::copy(self : Formatter) -> Formatter {
  match self {
    Formatter::Scalar(use_offset~, use_math_text~, power_min~, power_max~) =>
      Formatter::Scalar(use_offset~, use_math_text~, power_min~, power_max~)
    Formatter::Fixed(labels) => Formatter::Fixed(labels.copy())
    Formatter::Index(labels) => Formatter::Index(labels.copy())
    Formatter::Format(format) => Formatter::Format(format)
    Formatter::StrMethod(format) => Formatter::StrMethod(format)
    Formatter::Eng(unit~, places~, sep~) => Formatter::Eng(unit~, places~, sep~)
    Formatter::Percent(xmax~, decimals~, symbol~) =>
      Formatter::Percent(xmax~, decimals~, symbol~)
    Formatter::Log(base~, label_only_base~) =>
      Formatter::Log(base~, label_only_base~)
    Formatter::Null => Formatter::Null
    Formatter::Func(function) => Formatter::Func(function)
  }
}

///|
/// Format one value.  For position-dependent formatters use `format_values`.
pub fn Formatter::format_value(self : Formatter, value : Double) -> String {
  match self {
    Formatter::Scalar(use_offset~, use_math_text~, power_min~, power_max~) => {
      ignore(use_math_text)
      scalar_layout([value], None, use_offset, power_min, power_max).labels([
        value,
      ])[0]
    }
    Formatter::Fixed(labels) =>
      if labels.length() == 0 {
        ""
      } else {
        labels[0]
      }
    Formatter::Index(labels) => format_index(labels, value)
    Formatter::Format(format) => format_printf(format, value)
    Formatter::StrMethod(format) => format_str_method(format, value)
    Formatter::Eng(unit~, places~, sep~) =>
      format_engineering(value, unit, places, sep)
    Formatter::Percent(xmax~, decimals~, symbol~) =>
      format_percent(value, xmax, decimals, symbol, Double::abs(value))
    Formatter::Log(base~, label_only_base~) =>
      format_log(value, base, label_only_base)
    Formatter::Null => ""
    Formatter::Func(function) => function(value)
  }
}

///|
/// Format a complete tick list, preserving position-based formatter rules.
pub fn Formatter::format_values(
  self : Formatter,
  values : Array[Double],
) -> Array[String] {
  self.format_values_internal(values, None)
}

///|
/// Internal implementation shared by standalone and viewport-aware calls.
fn Formatter::format_values_internal(
  self : Formatter,
  values : Array[Double],
  view : @core.Limits?,
) -> Array[String] {
  match self {
    Formatter::Fixed(labels) => {
      let result : Array[String] = []
      for index in 0..<values.length() {
        if index < labels.length() {
          result.push(labels[index])
        } else {
          result.push("")
        }
      }
      result
    }
    Formatter::Index(labels) => values.map(value => format_index(labels, value))
    Formatter::Scalar(use_offset~, use_math_text~, power_min~, power_max~) => {
      ignore(use_math_text)
      scalar_layout(values, view, use_offset, power_min, power_max).labels(
        values,
      )
    }
    Formatter::Percent(xmax~, decimals~, symbol~) =>
      format_percent_values(values, xmax, decimals, symbol, view)
    Formatter::Null => values.map(_ => "")
    Formatter::StrMethod(format) => {
      let result : Array[String] = []
      for index, value in values {
        result.push(format_str_method_at(format, value, index))
      }
      result
    }
    _ => values.map(value => self.format_value(value))
  }
}

///|
/// Format a tick list when the caller knows the visible display range.
///
/// This is useful for percentage formatters: a viewport can be wider than the
/// supplied major ticks, and Matplotlib chooses automatic decimal places from
/// that viewport rather than from one tick value.
pub fn Formatter::format_values_with_range(
  self : Formatter,
  values : Array[Double],
  display_range : Double,
) -> Array[String] {
  match self {
    Formatter::Percent(xmax~, decimals~, symbol~) =>
      values.map(value => {
        format_percent(value, xmax, decimals, symbol, display_range)
      })
    _ => self.format_values(values)
  }
}

///|
/// Format labels using an optional viewport.  This named form is convenient
/// for renderers that already carry a `Limits` value and preserves the simple
/// `format_values(values)` call for standalone use.
pub fn Formatter::format_values_with_view(
  self : Formatter,
  values : Array[Double],
  view : @core.Limits?,
) -> Array[String] {
  self.format_values_internal(values, view)
}

///|
/// Return the additive offset selected for a scalar formatter.  This is
/// exposed separately so an axis or backend can render the offset text.
pub fn Formatter::offset(self : Formatter, values : Array[Double]) -> Double {
  self.offset_with_view(values, None)
}

///|
/// Return a scalar formatter's additive offset using an optional viewport.
pub fn Formatter::offset_with_view(
  self : Formatter,
  values : Array[Double],
  view : @core.Limits?,
) -> Double {
  match self {
    Formatter::Scalar(use_offset~, use_math_text~, power_min~, power_max~) => {
      ignore(use_math_text)
      scalar_layout(values, view, use_offset, power_min, power_max).offset
    }
    _ => 0.0
  }
}

///|
/// Return the scalar formatter's scientific multiplier and additive offset.
/// `use_offset=false` disables only the additive term. `use_math_text=true`
/// uses Unicode multiplication and superscripts instead of TeX markup.
pub fn Formatter::offset_label(
  self : Formatter,
  values : Array[Double],
) -> String {
  self.offset_label_with_view(values, None)
}

///|
/// Return the scalar formatter's scientific multiplier and additive offset
/// using an optional viewport.
pub fn Formatter::offset_label_with_view(
  self : Formatter,
  values : Array[Double],
  view : @core.Limits?,
) -> String {
  match self {
    Formatter::Scalar(use_offset~, use_math_text~, power_min~, power_max~) => {
      let layout = scalar_layout(values, view, use_offset, power_min, power_max)
      layout.offset_label(use_math_text)
    }
    _ => ""
  }
}
