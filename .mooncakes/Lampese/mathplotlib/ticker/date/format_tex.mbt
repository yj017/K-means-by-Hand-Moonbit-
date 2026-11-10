///|
fn tex_date_letter(value : Char) -> Bool {
  (value >= 'a' && value <= 'z') || (value >= 'A' && value <= 'Z')
}

///|
// Reproduce dates._wrap_in_tex: ASCII words remain outside mathdefault, while
// signs/colons are braced and spaces become explicit TeX spacing.
fn wrap_date_in_tex(value : String) -> String {
  let result = StringBuilder()
  let chars = value.to_array()
  result.write_string("$\\mathdefault{")
  let mut index = 0
  while index < chars.length() {
    if tex_date_letter(chars[index]) {
      result.write_string("}$")
      while index < chars.length() && tex_date_letter(chars[index]) {
        result.write_char(chars[index])
        index += 1
      }
      result.write_string("$\\mathdefault{")
    } else {
      match chars[index] {
        '-' => result.write_string("{-}")
        ':' => result.write_string("{:}")
        ' ' => result.write_string("\\;")
        char => result.write_char(char)
      }
      index += 1
    }
  }
  result.write_string("}$")
  result.to_string().replace_all(old="$\\mathdefault{}$", new="")
}
