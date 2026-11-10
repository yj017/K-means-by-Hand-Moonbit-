///|
fn render_panel(
  writer : @xml.Writer,
  figure : @render.Figure,
  panel : @render.Panel,
  scale : Scale,
  panel_index : Int32,
  position : (Double, Double, Double, Double),
  capture~ : DrawingCapture? = None,
) -> Unit raise @core.DataError {
  if panel.polar() is Some(config) {
    append_polar_panel(
      writer,
      figure,
      panel,
      config,
      panel_index,
      position,
      capture~,
    )
    return
  }
  let (left, top, plot_width, plot_height) = position
  // Earlier panels can change the limits of a shared axis in this frame.
  let (xmin, xmax) = panel.x_axis().view_interval_checked()
  let (ymin, ymax) = panel.y_axis().view_interval_checked()
  let scale : Scale = {
    xmin,
    xmax,
    ymin,
    ymax,
    x_axis_scale: scale.x_axis_scale,
    y_axis_scale: scale.y_axis_scale,
  }
  // The default child-axes zorder precedes the primary Axis artists. Evaluate
  // live secondary batches now; their XML can still follow the plot artists.
  let secondary_scale = scale
  let secondary_order = ordered_secondary_axes(panel)
  let secondary_x_bundles : Array[SecondaryTickBundle?] = Array::make(
    panel.secondary_x().length(),
    None,
  )
  let secondary_y_bundles : Array[SecondaryTickBundle?] = Array::make(
    panel.secondary_y().length(),
    None,
  )
  let mut owned_child_prepared = false
  for (horizontal, index, axis, _) in secondary_order {
    let prepared = if axis.prepare_draw() {
      owned_child_prepared = true
      // The original superclass draw evaluates its locator and calls the
      // child's aspect after the old-context map and parent-name reset.
      ignore(axis.positioned_aspect(left, top, plot_width, plot_height))
      let (lower, upper) = if horizontal {
        (scale.xmin, scale.xmax)
      } else {
        (scale.ymin, scale.ymax)
      }
      Some(secondary_axis_bundle(axis, [], lower, upper))
    } else {
      None
    }
    if horizontal {
      secondary_x_bundles[index] = prepared
    } else {
      secondary_y_bundles[index] = prepared
    }
  }
  // Child callbacks update the source parent's live transData before its
  // primary axes and data artists draw. Never redo finished child bundles.
  let scale = if owned_child_prepared {
    let (xmin, xmax) = panel.x_axis().view_interval_checked()
    let (ymin, ymax) = panel.y_axis().view_interval_checked()
    {
      xmin,
      xmax,
      ymin,
      ymax,
      x_axis_scale: panel.x_axis().scale(),
      y_axis_scale: panel.y_axis().scale(),
    }
  } else {
    scale
  }
  let x_bundle = numeric_axis_bundle(
    panel.x_axis(),
    @core.limits(scale.xmin, scale.xmax),
  )
  let (xmin, xmax) = panel.x_axis().view_interval_checked()
  let y_bundle = numeric_axis_bundle(
    panel.y_axis(),
    @core.limits(scale.ymin, scale.ymax),
  )
  let (ymin, ymax) = panel.y_axis().view_interval_checked()
  let scale : Scale = {
    xmin,
    xmax,
    ymin,
    ymax,
    x_axis_scale: scale.x_axis_scale,
    y_axis_scale: scale.y_axis_scale,
  }
  let x_ticks = x_bundle.major
  let y_ticks = y_bundle.major
  let x_minor_ticks = x_bundle.minor
  let y_minor_ticks = y_bundle.minor
  let x_labels = x_bundle.major_labels
  let y_labels = y_bundle.major_labels
  let x_minor_labels = x_bundle.minor_labels
  let y_minor_labels = y_bundle.minor_labels
  let x_offset_label = x_bundle.offset
  let y_offset_label = y_bundle.offset
  if panel.frame_visible() {
    append_grid(
      writer,
      scale,
      left,
      top,
      plot_width,
      plot_height,
      x_ticks,
      y_ticks,
      x_minor_ticks,
      y_minor_ticks,
      x_labels,
      y_labels,
      x_minor_labels,
      y_minor_labels,
      x_offset_label,
      y_offset_label,
      panel.x_axis().tick_position(),
      panel.y_axis().tick_position(),
      panel.show_x_tick_labels(),
      panel.show_y_tick_labels(),
      panel.x_axis().grid_visible(),
      panel.x_axis().grid_color(),
      panel.x_axis().grid_width(),
      panel.y_axis().grid_visible(),
      panel.y_axis().grid_color(),
      panel.y_axis().grid_width(),
      panel.x_axis().minor_grid_visible(),
      panel.x_axis().minor_grid_color(),
      panel.x_axis().minor_grid_width(),
      panel.y_axis().minor_grid_visible(),
      panel.y_axis().minor_grid_color(),
      panel.y_axis().minor_grid_width(),
      panel.x_axis().tick_label_size(),
      panel.y_axis().tick_label_size(),
    )
    append_axes(
      writer,
      scale,
      left,
      top,
      plot_width,
      plot_height,
      panel.spines(),
    )
  }
  for artist_index, artist in panel.artists() {
    let metadata = panel.hit_metadata(artist_index)
    // Filled-contour ownership cannot authorize another artist domain, even
    // with an unproven prepared Line/Step context. Keep its static paint and
    // completion, but never revive generic point or other-kind capture.
    let contourf_artist = match artist {
      @render.Artist::Polygon(_, _) | @render.Artist::CompoundPolygon(_, _) =>
        true
      _ => false
    }
    // Tripcolor owns only its original Polygon. Unknown/prepared or conflicting
    // owned metadata must not authorize any other-kind fallback.
    let tricolor_conflict = metadata.mesh() is Some(_) ||
      metadata.hexbin() is Some(_) ||
      metadata.discrete() is Some(_) ||
      metadata.stem() is Some(_) ||
      metadata.vector() is Some(_) ||
      metadata.barb() is Some(_) ||
      metadata.contour() is Some(_) ||
      metadata.contourf() is Some(_) ||
      metadata.band_horizontal() is Some(_)
    let tricolor = match (metadata.tricolor(), artist) {
      (Some(data), @render.Artist::Polygon(points, _)) if !tricolor_conflict &&
        data.matches_points(points) => Some(data)
      _ => None
    }
    let streamplot_conflict = metadata.mesh() is Some(_) ||
      metadata.hexbin() is Some(_) ||
      metadata.discrete() is Some(_) ||
      metadata.stem() is Some(_) ||
      metadata.vector() is Some(_) ||
      metadata.barb() is Some(_) ||
      metadata.contour() is Some(_) ||
      metadata.contourf() is Some(_) ||
      metadata.tricolor() is Some(_) ||
      metadata.band_horizontal() is Some(_)
    let streamplot_domain = match artist {
      @render.Artist::Line(_, _) => true
      _ => false
    }
    let capture = if (
        metadata.streamplot() is Some(view) &&
        (
          !view.enabled() ||
          !view.body() ||
          !streamplot_domain ||
          streamplot_conflict
        )
      ) ||
      (metadata.tricolor() is Some(_) && tricolor is None) ||
      (metadata.barb() is Some(view) && !view.enabled()) ||
      (metadata.contour() is Some(view) && !view.enabled()) ||
      (
        metadata.contourf() is Some(data) &&
        (!data.enabled() || !contourf_artist)
      ) {
      None
    } else {
      capture
    }
    match artist {
      @render.Artist::Line(points, style) =>
        match panel.prepare_line(points) {
          Some(context) => {
            let prepared_discrete = if metadata.streamplot() is Some(_) ||
              metadata.barb() is Some(_) ||
              metadata.contour() is Some(_) {
              None
            } else {
              context.discrete()
            }
            let discrete = match prepared_discrete {
              Some(data) =>
                discrete_line_for_paint(
                  Some(data),
                  context.points(),
                  context.first_style(),
                )
              None => None
            }
            append_line_context(
              writer,
              scale,
              left,
              top,
              plot_width,
              plot_height,
              context,
              on_segment=discrete_line_capture(
                capture,
                discrete,
                panel_index,
                artist_index,
                scale,
                position,
                metadata.series(),
              ),
            )
            if capture is Some(hits) &&
              discrete is None &&
              metadata.streamplot() is None &&
              metadata.stem() is None &&
              metadata.barb() is None &&
              metadata.contour() is None &&
              (
                metadata.discrete() is None ||
                discrete_line_visible(context.first_style())
              ) &&
              context.first_style().width() > 0.0 &&
              context.first_style().line_stroke().linestyle() != "None" {
              let points = match context.hit_points() {
                Some(points) => points
                None => context.points()
              }
              collect_drawing_points(
                hits,
                panel_index,
                artist_index,
                points,
                scale,
                position,
                panel,
                metadata,
                @drawing.HitKind::Line,
              )
            }
          }
          None => {
            let streamplot = streamplot_line_for_paint(
              metadata.streamplot(),
              points,
              style,
            )
            let contour = contour_line_for_paint(
              metadata.contour(),
              points,
              style,
            )
            let barb = barb_stroke_for_paint(metadata.barb(), points, style)
            let stem = stem_rod_for_paint(metadata.stem(), points, style)
            let discrete = discrete_line_for_paint(
              metadata.discrete(),
              points,
              style,
            )
            append_line_artist(
              writer,
              scale,
              left,
              top,
              plot_width,
              plot_height,
              points,
              style,
              on_segment=if streamplot is Some(_) {
                streamplot_line_capture(
                  capture, streamplot, panel_index, artist_index, scale, position,
                )
              } else if contour is Some(_) {
                contour_line_capture(
                  capture, contour, panel_index, artist_index, scale, position,
                )
              } else if barb is Some(_) {
                barb_stroke_capture(
                  capture, barb, panel_index, artist_index, scale, position,
                )
              } else if stem is Some(_) {
                stem_rod_capture(
                  capture,
                  stem,
                  panel_index,
                  artist_index,
                  scale,
                  position,
                  metadata.series(),
                )
              } else {
                discrete_line_capture(
                  capture,
                  discrete,
                  panel_index,
                  artist_index,
                  scale,
                  position,
                  metadata.series(),
                )
              },
            )
            if capture is Some(hits) &&
              discrete is None &&
              metadata.streamplot() is None &&
              metadata.stem() is None &&
              metadata.barb() is None &&
              metadata.contour() is None &&
              (metadata.discrete() is None || discrete_line_visible(style)) &&
              style.width() > 0.0 &&
              style.line_stroke().linestyle() != "None" {
              collect_drawing_points(
                hits,
                panel_index,
                artist_index,
                points,
                scale,
                position,
                panel,
                metadata,
                @drawing.HitKind::Line,
              )
            }
          }
        }
      @render.Artist::Scatter(points, style) => {
        let stem = stem_heads_for_paint(metadata.stem(), points, style)
        append_scatter(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          points,
          style,
          on_circle=if metadata.barb() is Some(_) {
            barb_calm_capture(
              capture,
              barb_calm_for_paint(metadata.barb(), points, style),
              panel_index,
              artist_index,
              position,
              style.radius(),
            )
          } else {
            stem_head_capture(
              capture,
              stem,
              panel_index,
              artist_index,
              position,
              metadata.series(),
            )
          },
        )
        if capture is Some(hits) &&
          metadata.stem() is None &&
          metadata.barb() is None {
          collect_drawing_points(
            hits,
            panel_index,
            artist_index,
            points,
            scale,
            position,
            panel,
            metadata,
            @drawing.HitKind::Scatter,
          )
        }
      }
      @render.Artist::PathCollection(points, styles) => {
        append_path_collection(
          writer, scale, left, top, plot_width, plot_height, points, styles,
        )
        if capture is Some(hits) {
          collect_drawing_points(
            hits,
            panel_index,
            artist_index,
            points,
            scale,
            position,
            panel,
            metadata,
            @drawing.HitKind::Scatter,
            count=Int32::min(points.length(), styles.length()),
          )
        }
      }
      @render.Artist::Bar(points, style) =>
        append_bars(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          points,
          style,
          on_bar=capture.map(hits => {
            rectangle => {
              collect_drawing_bar(
                hits, panel_index, artist_index, rectangle, panel, metadata, position,
                false,
              )
            }
          }),
        )
      @render.Artist::BarH(points, style) =>
        append_barh(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          points,
          style,
          on_bar=capture.map(hits => {
            rectangle => {
              collect_drawing_bar(
                hits, panel_index, artist_index, rectangle, panel, metadata, position,
                true,
              )
            }
          }),
        )
      @render.Artist::BarSegments(segments, horizontal, style) =>
        append_bar_segments(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          segments,
          horizontal,
          style,
          on_bar=capture.map(hits => {
            rectangle => {
              collect_drawing_bar(
                hits, panel_index, artist_index, rectangle, panel, metadata, position,
                horizontal,
              )
            }
          }),
        )
      @render.Artist::FillBetween(upper, lower, style) =>
        append_fill_between(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          upper,
          lower,
          style,
          on_segment=capture.map(hits => {
            (segment_upper, segment_lower, source_start) => {
              collect_drawing_band(
                hits, panel_index, artist_index, segment_upper, segment_lower, source_start,
                scale, position, metadata,
              )
            }
          }),
        )
      @render.Artist::Polygon(points, style) => {
        let contourf = match metadata.contourf() {
          Some(data) if data.matches_polygon(points) => Some(data)
          _ => None
        }
        append_polygon(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          points,
          style,
          on_polygon=capture.map(hits => {
            visible => {
              collect_tripcolor_region(
                hits,
                tricolor,
                panel_index,
                artist_index,
                visible,
                scale,
                position,
                style,
                figure.width(),
                figure.height(),
              )
              collect_contourf_region(
                hits,
                contourf,
                panel_index,
                artist_index,
                [visible],
                false,
                scale,
                position,
                style,
                figure.width(),
                figure.height(),
              )
              collect_barb_flag(
                hits,
                metadata.barb(),
                panel_index,
                artist_index,
                visible,
                scale,
                position,
                style,
              )
              collect_drawing_mesh(
                hits, panel_index, artist_index, visible, scale, position, metadata,
              )
              collect_drawing_hexbin(
                hits, panel_index, artist_index, visible, scale, position, metadata,
                style,
              )
              collect_drawing_stairs_face(
                hits, panel_index, artist_index, visible, scale, position, metadata,
                style,
              )
            }
          }),
        )
      }
      @render.Artist::CompoundPolygon(polygons, style) => {
        let contourf = match metadata.contourf() {
          Some(data) if data.matches_rings(polygons) => Some(data)
          _ => None
        }
        append_compound_polygon(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          polygons,
          style,
          on_polygons=capture.map(hits => {
            visible => {
              collect_contourf_region(
                hits,
                contourf,
                panel_index,
                artist_index,
                visible,
                true,
                scale,
                position,
                style,
                figure.width(),
                figure.height(),
              )
            }
          }),
        )
      }
      @render.Artist::GouraudTriangle(points, colors) =>
        append_gouraud_triangle(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          points,
          colors,
          "gouraud-\{panel_index}-\{artist_index}",
        )
      @render.Artist::HLine(value, style) =>
        append_reference_line(
          writer, scale, left, top, plot_width, plot_height, value, true, style,
        )
      @render.Artist::VLine(value, style) =>
        append_reference_line(
          writer, scale, left, top, plot_width, plot_height, value, false, style,
        )
      @render.Artist::AxLine(point, direction, style) =>
        append_axline(
          writer, scale, left, top, plot_width, plot_height, point, direction, style,
        )
      @render.Artist::HSpan(lower, upper, style) =>
        append_span(
          writer, scale, left, top, plot_width, plot_height, lower, upper, true,
          style,
        )
      @render.Artist::VSpan(lower, upper, style) =>
        append_span(
          writer, scale, left, top, plot_width, plot_height, lower, upper, false,
          style,
        )
      @render.Artist::Text(x, y, value, style) =>
        append_artist_text(
          writer,
          map_x(scale, left, plot_width, x),
          map_y(scale, top, plot_height, y),
          value,
          style,
        )
      @render.Artist::Annotation(value) =>
        append_annotation(
          writer, figure, scale, left, top, plot_width, plot_height, value,
        )
      @render.Artist::ErrorBar(points, yerr, xerr, style) =>
        append_errorbar(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          points,
          yerr,
          xerr,
          style,
          on_sample=capture.map(hits => {
            sample => {
              collect_drawing_errorbar(
                hits, panel_index, artist_index, sample, metadata, position,
              )
            }
          }),
        )
      @render.Artist::Image(data, vmin, vmax, cmap) => {
        let norm = match (vmin, vmax) {
          (Some(lower), Some(upper)) =>
            @colors.linear_color_norm(
              try! @colors.normalize(vmin=lower, vmax=upper),
            )
          (Some(lower), None) =>
            @colors.linear_color_norm(try! @colors.normalize(vmin=lower))
          (None, Some(upper)) =>
            @colors.linear_color_norm(try! @colors.normalize(vmax=upper))
          (None, None) => @colors.linear_color_norm(try! @colors.normalize())
        }
        append_image(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          data,
          norm,
          cmap,
          @render.ImageOrigin::Upper,
          None,
          1.0,
          @render.ImageInterpolation::Nearest,
          on_cell=capture.map(hits => {
            cell => {
              collect_drawing_cell(
                hits, panel_index, artist_index, cell, position,
              )
            }
          }),
        )
      }
      @render.Artist::ImageNorm(
        data,
        norm,
        cmap,
        origin,
        extent,
        alpha,
        interpolation
      ) =>
        append_image(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          data,
          norm,
          cmap,
          origin,
          extent,
          alpha,
          interpolation,
          on_cell=capture.map(hits => {
            cell => {
              collect_drawing_cell(
                hits, panel_index, artist_index, cell, position,
              )
            }
          }),
        )
      @render.Artist::ColorImage(data, origin, extent, alpha, interpolation) =>
        append_color_image(
          writer, scale, left, top, plot_width, plot_height, data, origin, extent,
          alpha, interpolation,
        )
      @render.Artist::Table(table) =>
        append_table(writer, left, top, plot_width, plot_height, table)
      @render.Artist::Pie(values, labels, colors, start_angle) =>
        append_pie(
          writer,
          left,
          top,
          plot_width,
          plot_height,
          values,
          labels,
          colors,
          start_angle,
          on_slice=capture.map(hits => {
            (index, cx, cy, radius, start, sweep, fraction) => {
              collect_drawing_pie(
                hits,
                panel_index,
                artist_index,
                index,
                values[index],
                labels,
                metadata.series(),
                cx,
                cy,
                radius,
                start,
                sweep,
                fraction,
                position,
              )
            }
          }),
        )
      @render.Artist::Donut(values, labels, colors, start_angle, inner_radius) =>
        append_donut(
          writer,
          left,
          top,
          plot_width,
          plot_height,
          values,
          labels,
          colors,
          start_angle,
          inner_radius,
          on_slice=capture.map(hits => {
            (index, cx, cy, inner, outer, start, sweep, fraction) => {
              collect_drawing_donut(
                hits,
                panel_index,
                artist_index,
                index,
                values[index],
                labels,
                metadata.series(),
                cx,
                cy,
                inner,
                outer,
                start,
                sweep,
                fraction,
                position,
              )
            }
          }),
        )
      @render.Artist::BoxPlot(stats, horizontal, style) =>
        append_boxplot(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          stats,
          horizontal,
          style,
          on_box=capture.map(hits => {
            sample => {
              collect_drawing_boxplot(
                hits, panel_index, artist_index, sample, metadata, position,
              )
            }
          }),
        )
      @render.Artist::Quiver(points, vectors, style) => {
        let source = vector_for_paint(metadata.vector(), points, vectors, style)
        append_quiver(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          points,
          vectors,
          style,
          on_arrow=vector_capture(
            capture,
            source,
            panel_index,
            artist_index,
            position,
            metadata.series(),
          ),
        )
      }
      @render.Artist::Violin(
        stats,
        positions,
        widths,
        horizontal,
        side,
        showmeans,
        showextrema,
        showmedians,
        body_style,
        line_style,
        opacity
      ) =>
        append_violin(
          writer,
          scale,
          left,
          top,
          plot_width,
          plot_height,
          stats,
          positions,
          widths,
          horizontal,
          side,
          showmeans,
          showextrema,
          showmedians,
          body_style,
          line_style,
          opacity,
          on_body=capture.map(hits => {
            body => {
              collect_drawing_violin_body(
                hits, panel_index, artist_index, body, scale, position, metadata,
              )
            }
          }),
          on_line=capture.map(hits => {
            line => {
              collect_drawing_violin_line(
                hits, panel_index, artist_index, line, metadata, position,
              )
            }
          }),
        )
    }
  }
  if panel.frame_visible() {
    for (horizontal, index, axis, _) in secondary_order {
      if horizontal {
        append_secondary_x_axis(
          writer,
          secondary_scale,
          left,
          top,
          plot_width,
          plot_height,
          x_ticks,
          axis,
          prepared=secondary_x_bundles[index],
        )
      } else {
        append_secondary_y_axis(
          writer,
          secondary_scale,
          left,
          top,
          plot_width,
          plot_height,
          y_ticks,
          axis,
          prepared=secondary_y_bundles[index],
        )
      }
    }
  }
  append_legend(
    writer,
    left,
    top,
    plot_width,
    plot_height,
    panel.legend(),
    panel.legend_position(),
    on_box=capture.map(snapshot => {
      rectangle => snapshot.exclusions.push((panel_index, rectangle))
    }),
  )
  match panel.title() {
    Some(value) =>
      append_text(
        writer,
        left + plot_width / 2.0,
        top - 18.0,
        value,
        "middle",
        15,
      )
    None => ()
  }
  if panel.frame_visible() {
    match panel.x_axis().label() {
      Some(value) =>
        append_text(
          writer,
          left + plot_width / 2.0,
          top + plot_height + 38.0,
          value,
          "middle",
          13,
        )
      None => ()
    }
    match panel.y_axis().label() {
      Some(value) =>
        append_text(
          writer,
          left - 40.0,
          top + plot_height / 2.0,
          value,
          "middle",
          13,
        )
      None => ()
    }
  }
}
