///|
// Membership follows the source Grouper independently of Figure's panel list.
// Explicit retained handles keep targets alive; Python weak-reference expiry is
// outside this typed Scene profile.
priv struct SharedAxesGroup {
  id : Int32
  members : Array[@ref.Ref[AxesData]]
}

///|
fn Axes::ensure_shared_registration(
  self : Axes,
  horizontal : Bool,
) -> SharedAxesGroup {
  let existing = if horizontal {
    self.state.val.share_x_members
  } else {
    self.state.val.share_y_members
  }
  if existing is Some(group) {
    return group
  }
  let group : SharedAxesGroup = {
    id: self.figure.allocate_share_group(1),
    members: [self.state],
  }
  if horizontal {
    self.state.val.share_x_members = Some(group)
    self.state.val.share_x_group = Some(group.id)
    self.state.val.share_x_order = self.figure.share_x_next_order
    self.figure.share_x_next_order += 1L
  } else {
    self.state.val.share_y_members = Some(group)
    self.state.val.share_y_group = Some(group.id)
    self.state.val.share_y_order = self.figure.share_y_next_order
    self.figure.share_y_next_order += 1L
  }
  group
}

///|
fn Axes::join_shared_axis(
  self : Axes,
  target : @ref.Ref[AxesData],
  horizontal : Bool,
) -> Unit {
  // Grouper.join registers self before its argument, including fresh re-joins.
  let own = self.ensure_shared_registration(horizontal)
  let other_axes : Axes = { figure: self.figure, state: target, }
  let other = other_axes.ensure_shared_registration(horizontal)
  if physical_equal(own, other) {
    return
  }
  let (destination, source) = if own.members.length() < other.members.length() {
    (other, own)
  } else {
    (own, other)
  }
  for state in source.members {
    destination.members.push(state)
  }
  destination.members.sort_by((left, right) => {
    let first = if horizontal {
      left.val.share_x_order
    } else {
      left.val.share_y_order
    }
    let second = if horizontal {
      right.val.share_x_order
    } else {
      right.val.share_y_order
    }
    first.compare(second)
  })
  for state in destination.members {
    if horizontal {
      state.val.share_x_members = Some(destination)
      state.val.share_x_group = Some(destination.id)
    } else {
      state.val.share_y_members = Some(destination)
      state.val.share_y_group = Some(destination.id)
    }
  }
}

///|
fn Axes::unregister_shared_axis(
  self : Axes,
  horizontal : Bool,
) -> Array[@ref.Ref[AxesData]] {
  let existing = if horizontal {
    self.state.val.share_x_members
  } else {
    self.state.val.share_y_members
  }
  let remaining = match existing {
    Some(group) => {
      group.members.retain(state => !physical_equal(state, self.state))
      group.members.copy()
    }
    None => []
  }
  if horizontal {
    self.state.val.share_x_members = None
    self.state.val.share_x_group = None
  } else {
    self.state.val.share_y_members = None
    self.state.val.share_y_group = None
  }
  remaining
}
