///|
fn svg_content(content : SvgContent) -> @svg.Svg raise AdapterError {
  match content {
    Text(value) => @svg.text(value)
    Element(name, attributes, children) => {
      let attrs = @svg.Attrs::build()
      for (key, value) in attributes {
        svg_attribute(attrs, name, key, value)
      }
      @svg.node(name, attrs, children.map(svg_content))
    }
  }
}

///|
fn highlight(
  point : @drawing.HitPoint,
  selected : Bool,
  id : String,
) -> @svg.Svg {
  let kind = if selected { "selected" } else { "hover" }
  @svg.node(
    "circle",
    @svg.Attrs::build()
    .cx(point.screen_x.to_string())
    .cy(point.screen_y.to_string())
    .r(if selected { "6" } else { "5" })
    .fill("#ffffff")
    .stroke(if selected { "#286b73" } else { "#52657b" })
    .stroke_width("2")
    .vector_effect("non-scaling-stroke")
    .pointer_events("none")
    .data_set("moonplot-" + kind, point.point_index.to_string())
    .data_set("testid", id + "-" + kind),
    [],
  )
}

///|
// New Polar-kind held state needs the same proven circle as pointer selection.
// Existing ordinary/legacy Drawing presentation retains its previous contract.
fn frame_point_presentable(
  drawing : @drawing.Drawing,
  point : @drawing.HitPoint,
) -> Bool {
  match tooltip_info(drawing, point) {
    Some(info) =>
      if info.kind is Polar || info.kind is PolarBar {
        drawing.polar_circle(point.panel_index) is Some(_)
      } else {
        true
      }
    None => false
  }
}

///|
fn frame_highlight(
  drawing : @drawing.Drawing,
  point : @drawing.HitPoint,
  selected : Bool,
  id : String,
) -> @svg.Svg {
  let marker = highlight(point, selected, id)
  match drawing.polar_circle(point.panel_index) {
    None => marker
    Some((cx, cy, radius)) => {
      let kind = if selected { "selected" } else { "hover" }
      // Source SVG resources use moonplot-resource-. This separate namespace
      // remains injective for arbitrary chart IDs and cannot alias source IDs.
      let clip_id = "moonplot-decoration-" +
        resource_component(id) +
        "-polar-\{point.panel_index}-\{kind}"
      @svg.node("g", @svg.Attrs::build(), [
        @svg.node("defs", @svg.Attrs::build(), [
          @svg.node(
            "clipPath",
            @svg.Attrs::build().id(clip_id).clip_path_units("userSpaceOnUse"),
            [
              @svg.node(
                "circle",
                @svg.Attrs::build()
                .cx(cx.to_string())
                .cy(cy.to_string())
                .r(radius.to_string()),
                [],
              ),
            ],
          ),
        ]),
        @svg.node(
          "g",
          @svg.Attrs::build()
          .clip_path("url(#" + clip_id + ")")
          .data_set("moonplot-decoration", kind)
          .data_set("moonplot-panel", point.panel_index.to_string()),
          [marker],
        ),
      ])
    }
  }
}

///|
fn drawing_svg(
  content : SvgContent,
  drawing : @drawing.Drawing,
  id : String,
  hovered : @drawing.HitPoint?,
  selected : @drawing.HitPoint?,
) -> @html.Html raise AdapterError {
  let (attributes, children) = match content {
    Element("svg", attributes, children) => (attributes, children)
    _ => raise InvalidSvg("The root element must be svg")
  }
  let attrs = @svg.Attrs::build()
  for (key, value) in attributes {
    if key == "xmlns" {
      if value != "http://www.w3.org/2000/svg" {
        raise InvalidSvg("Unsupported SVG namespace: " + value)
      }
    } else {
      svg_attribute(attrs, "svg", key, value)
    }
  }
  ignore(
    attrs
    .id(id + "-svg")
    .data_set("moonplot-root", id)
    .style("width", "100%")
    .style("height", "auto")
    .style("display", "block"),
  )
  let nodes = children.map(svg_content)
  if hovered is Some(point) && selected != Some(point) {
    nodes.push(frame_highlight(drawing, point, false, id))
  }
  if selected is Some(point) {
    nodes.push(frame_highlight(drawing, point, true, id))
  }
  @svg.svg(xmlns="http://www.w3.org/2000/svg", attrs~, nodes)
}

///|
fn event_hit(
  drawing : @drawing.Drawing,
  event : @dom.MouseEvent,
  radius : Double,
  mode : @drawing.HitMode,
) -> @drawing.HitPoint? {
  let container = match event.current_target().to_option() {
    Some(target) => target.to_element()
    None => None
  }
  let svg_root = match container {
    Some(element) => element.query_selector("svg[data-moonplot-root]")
    None => None
  }
  match svg_root {
    Some(root) =>
      match
        svg_client_coordinates(
          drawing,
          root,
          event.get_client_x(),
          event.get_client_y(),
        ) {
        Some((x, y, scale)) =>
          drawing.hit_test(x, y, radius=radius / scale, mode~)
        None => None
      }
    None => None
  }
}

///|
/// Build real SVG nodes and HTML event handlers using public Rabbita APIs.
/// The application supplies a new drawing when its data or visibility changes.
/// Use XNearest to select actual line/error-bar samples by horizontal position in a panel.
/// tooltip replaces the floating content; tooltip_class and CSS variables style it.
/// Turning tooltip_visible off keeps all interaction messages enabled.
pub fn view(
  drawing : @drawing.Drawing,
  id~ : String,
  on_event~ : (Interaction) -> @rabbita.Cmd,
  hovered? : @drawing.HitPoint,
  selected? : @drawing.HitPoint,
  legend~ : Array[LegendItem] = [],
  hit_radius~ : Double = 10.0,
  hit_mode~ : @drawing.HitMode = Nearest,
  tooltip? : (@drawing.HitInfo) -> @rabbita.Html,
  tooltip_visible~ : Bool = true,
  tooltip_class~ : String = "",
) -> @rabbita.Html raise AdapterError {
  let parsed = parse_svg(drawing.svg())
  validate_drawing(drawing, parsed)
  let hovered = hovered.filter(point => frame_point_presentable(drawing, point))
  let selected = selected.filter(point => {
    frame_point_presentable(drawing, point)
  })
  let chart = drawing_svg(
    scope_svg_resources(parsed, id),
    drawing,
    id,
    hovered,
    selected,
  )
  let viewport = [chart]
  if tooltip_visible &&
    hovered is Some(point) &&
    tooltip_info(drawing, point) is Some(info) {
    viewport.push(tooltip_node(info, id, tooltip_class, tooltip))
  }
  let children = [
    @html.div(
      class="moonplot-viewport",
      attrs=@html.Attrs::build()
        .data_set("testid", id + "-viewport")
        .on_mousemove(event => {
          on_event(Hover(event_hit(drawing, event, hit_radius, hit_mode)))
        })
        .on_mouseleave(_ => on_event(Hover(None)))
        .on_click(event => {
          on_event(Click(event_hit(drawing, event, hit_radius, hit_mode)))
        }),
      viewport,
    ),
  ]
  if legend.length() > 0 {
    children.push(
      @html.div(
        class="moonplot-legend",
        attrs=@html.Attrs::build()
          .role("group")
          .aria_label("Chart series")
          .data_set("testid", id + "-legend"),
        legend.map(item => {
          @html.button(
            type_="button",
            class="moonplot-series",
            attrs=@html.Attrs::build()
              .data_set("moonplot-series", item.key)
              .aria_pressed(item.visible.to_string())
              .on_click(_ => on_event(ToggleSeries(item.key))),
            [
              @html.span(
                class="moonplot-swatch",
                attrs=@html.Attrs::build()
                  .aria_hidden("true")
                  .style("background-color", item.color),
                "",
              ),
              @html.span(item.label),
            ],
          )
        }),
      ),
    )
  }
  @html.div(
    id~,
    class="moonplot",
    attrs=@html.Attrs::build().data_set("testid", id),
    children,
  )
}
