///|
// Explicit scale changes install fresh named ticker objects in source order.
// The caller restores the four default flags only after all setters succeed.
fn Axis::install_scale_defaults(self : Axis) -> Unit raise @core.DataError {
  let geometry = self.scale()
  match geometry {
    @scale.Scale::Linear => {
      self.set_locator(@ticker.AutoLocator::new().as_locator())
      self.set_named_formatter(
        @ticker.ScalarFormatter::new().as_base_formatter(),
      )
      self.set_minor_named_formatter(
        @ticker.NullFormatter::new().as_base_formatter(),
      )
      if @config.minor_ticks_visible(horizontal=self.tick_horizontal) {
        self.set_minor_locator(
          @ticker.AutoMinorLocator::new().as_minor_locator(),
        )
      } else {
        self.set_minor_locator(@ticker.NullLocator::new().as_minor_locator())
      }
    }
    @scale.Scale::Log => {
      self.set_locator(@ticker.LogLocator::new(base=10.0).as_locator())
      self.set_named_formatter(
        @ticker.LogFormatterSciNotation::new().as_base_formatter(),
      )
      self.set_minor_locator(
        @ticker.LogLocator::new(base=10.0, subs=None).as_minor_locator(),
      )
      self.set_minor_named_formatter(
        @ticker.LogFormatterSciNotation::new().as_base_formatter(),
      )
    }
    @scale.Scale::SymLog(base~, ..) => {
      self.set_locator(
        @ticker.SymmetricalLogLocator::new(transform=geometry).as_locator(),
      )
      self.set_named_formatter(
        @ticker.LogFormatterSciNotation::new(
          base=@ticker.LogValue::Numeric(@ticker.ScalarNumber::Number(base)),
        ).as_base_formatter(),
      )
      self.set_minor_locator(
        @ticker.SymmetricalLogLocator::new(transform=geometry).as_minor_locator(),
      )
      self.set_minor_named_formatter(
        @ticker.NullFormatter::new().as_base_formatter(),
      )
    }
    @scale.Scale::Asinh(linear_width~) => {
      // Original axis.set evaluates all three RHS constructors first.
      let major = @ticker.AsinhLocator::new(linear_width, base=10.0)
      let minor = @ticker.AsinhLocator::new(
        linear_width,
        base=10.0,
        subs=Some(@ticker.AsinhSubs::Tuple(@ticker.asinh_default_minor_subs())),
      )
      let minor_formatter = @ticker.NullFormatter::new()
      self.set_locator(major.as_locator())
      self.set_minor_locator(minor.as_minor_locator())
      self.set_minor_named_formatter(minor_formatter.as_base_formatter())
      self.set_named_formatter(
        @ticker.LogFormatterSciNotation::new().as_base_formatter(),
      )
    }
    @scale.Scale::Logit(..) => {
      self.set_locator(@ticker.LogitLocator::new().as_locator())
      self.set_named_formatter(
        @ticker.LogitFormatter::new().as_base_formatter(),
      )
      self.set_minor_locator(
        @ticker.LogitLocator::new(minor=true).as_minor_locator(),
      )
      self.set_minor_named_formatter(
        @ticker.LogitFormatter::new(
          minor=@ticker.LogValue::Numeric(@ticker.ScalarNumber::Boolean(true)),
        ).as_base_formatter(),
      )
    }
  }
}
