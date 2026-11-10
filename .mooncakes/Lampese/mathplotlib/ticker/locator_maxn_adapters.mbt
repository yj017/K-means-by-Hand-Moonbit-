///|
pub fn MaxNLocator::as_locator(self : MaxNLocator) -> Locator {
  NamedMaxN(self)
}

///|
pub fn MaxNLocator::as_minor_locator(self : MaxNLocator) -> MinorLocator {
  NamedMaxN(self)
}

///|
pub fn AutoLocator::as_locator(self : AutoLocator) -> Locator {
  NamedAuto(self)
}

///|
pub fn AutoLocator::as_minor_locator(self : AutoLocator) -> MinorLocator {
  NamedAuto(self)
}

///|
pub fn Locator::maxn_locator(self : Locator) -> MaxNLocator? {
  match self {
    NamedMaxN(value) => Some(value)
    _ => None
  }
}

///|
pub fn Locator::auto_locator(self : Locator) -> AutoLocator? {
  match self {
    NamedAuto(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::maxn_locator(self : MinorLocator) -> MaxNLocator? {
  match self {
    NamedMaxN(value) => Some(value)
    _ => None
  }
}

///|
pub fn MinorLocator::auto_locator(self : MinorLocator) -> AutoLocator? {
  match self {
    NamedAuto(value) => Some(value)
    _ => None
  }
}
