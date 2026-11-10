///|
fn barb_derived_finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
fn checked_barb_counts(
  effective : Double,
  half_increment : Double,
  full_increment : Double,
  flag_increment : Double,
  existing_components : Int32,
) -> (Int32, Int32, Int32) raise @core.DataError {
  // Keep the original floating-point operations. Conversion follows only once
  // every derived count and the resulting array length is representable.
  let flags = (effective / flag_increment).floor()
  let after_flags = effective - flags * flag_increment
  let fulls = (after_flags / full_increment).floor()
  let remainder = after_flags - fulls * full_increment
  let half = if remainder + 1.0e-12 >= half_increment { 1 } else { 0 }
  let components = 1.0 +
    flags.max(0.0) +
    fulls.max(0.0) +
    Double::from_int(half)
  if !barb_derived_finite(effective) ||
    !barb_derived_finite(flags) ||
    !barb_derived_finite(after_flags) ||
    !barb_derived_finite(fulls) ||
    !barb_derived_finite(remainder) ||
    !barb_derived_finite(components) ||
    flags < -2147483648.0 ||
    flags > 2147483647.0 ||
    fulls < -2147483648.0 ||
    fulls > 2147483647.0 ||
    components > 2147483647.0 - Double::from_int(existing_components) {
    raise @core.DataError::InvalidQuiver(
      message="barb derived component counts must be finite and representable",
    )
  }
  (flags.to_int(), fulls.to_int(), half)
}
