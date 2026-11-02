# frozen_string_literal: true

require 'adwaita'

require_relative 'chart'
require_relative 'formatters'

# RingsChartItem is one ring sector.
#
# Ported from upstream's RingschartItem in src/baobab-ringschart.vala.
class RingsChartItem < ChartItem
  attr_accessor :min_radius, :max_radius, :start_angle, :angle, :continued

  def initialize
    super
    @min_radius = 0.0
    @max_radius = 0.0
    @start_angle = 0.0
    @angle = 0.0
    @continued = false
  end

  def continued? = @continued
end

# RingsChart draws the scan as concentric rings, the centre being the folder
# the chart is rooted at and each ring out from it a level deeper.
#
# Ported from upstream's src/baobab-ringschart.vala: the sector geometry, the
# total size printed in the middle of the central disk, the thicker arc that
# marks a folder with children beyond the visible depth, and the sub-folder
# tooltips that fade in a second after the pointer settles on a sector.
#
class RingsChart < Chart
  ITEM_BORDER_WIDTH = 1
  ITEM_MIN_ANGLE = 0.03
  EDGE_ANGLE = 0.004

  # Twice the GTK tooltip timeout, as upstream has it.
  SUBTIP_TIMEOUT = 1000

  SUBTIP_PADDING = 6
  SUBTIP_HPADDING = 10
  SUBTIP_RADIUS = 9

  def initialize
    super
    @drawing_subtips = false
    @subtip_items = []
    @tips_timeout_id = nil
    add_css_class('ringschart')
  end

  def create_chart_item = RingsChartItem.new

  # Upstream connects subtips_update to the max-depth, highlighted-item and
  # root notifications.
  def max_depth_changed = subtips_update
  def highlighted_item_changed = subtips_update

  # Upstream's calculate_item_geometry.
  def calculate_item_geometry(item)
    item.continued = false
    item.visible = false

    thickness.then do |step|
      case item.parent
      when nil then place_root(item, step)
      else place_sector(item, step)
      end
    end
  end

  # Upstream's draw_item.
  def draw_item(context, item, highlighted)
    collect_subtip(item)
    context.set_line_width(ITEM_BORDER_WIDTH)

    case item.depth
    when 0 then draw_center(context, item)
    else draw_sector(context, item, highlighted)
    end
  end

  # Upstream's post_draw, which draws the sub-folder tooltips.
  def post_draw(context)
    if @drawing_subtips
      draw_subtips(context)
    end
  end

  # Upstream's is_point_over_item.
  def point_over_item?(item, x, y)
    (x - center_x).then do |dx|
      (y - center_y).then do |dy|
        within_sector?(item, Math.sqrt(dx * dx + dy * dy), normalized_angle(dy, dx))
      end
    end
  end

  # Upstream's get_item_rectangle.
  def get_item_rectangle(item)
    bounds(item).then do |left, top, right, bottom|
      item.rect = Gdk::Rectangle.new(
        left.to_i,
        top.to_i,
        (right - left).to_i,
        (bottom - top).to_i,
      )
    end
  end

  def can_zoom_out? = max_depth < MAX_DEPTH
  def can_zoom_in? = max_depth > MIN_DEPTH

  private

    def center_x = width / 2.0
    def center_y = height / 2.0
    def max_radius = [width / 2.0, height / 2.0].min
    def thickness = max_radius / (max_depth + 1)

    def place_root(item, step)
      item.min_radius = 0
      item.max_radius = step
      item.start_angle = 0
      item.angle = 2 * Math::PI
      finish_placing(item)
    end

    def place_sector(item, step)
      item.min_radius = item.depth * step
      item.angle = item.parent.angle * item.rel_size / 100

      if item.depth <= max_depth && item.angle >= ITEM_MIN_ANGLE
        item.max_radius = item.min_radius + step
        item.start_angle = item.parent.start_angle + item.parent.angle * item.rel_start / 100
        item.continued = !item.results.empty? && item.depth == max_depth
        item.parent.has_visible_children = true
        finish_placing(item)
      end
    end

    def finish_placing(item)
      item.visible = true
      get_item_rectangle(item)
    end

    def within_sector?(item, radius, angle)
      radius >= item.min_radius &&
        radius <= item.max_radius &&
        angle >= item.start_angle &&
        angle <= item.start_angle + item.angle
    end

    def normalized_angle(dy, dx)
      Math.atan2(dy, dx).then { |angle| angle.positive? ? angle : angle + 2 * Math::PI }
    end

    # Upstream prints the root's size in the middle of the central disk and
    # rings the disk with the border colour.
    def draw_center(context, item)
      size_layout(item).then do |layout, extents|
        if extents.width < 2 * item.max_radius
          draw_layout(
            context,
            layout,
            center_x - extents.width / 2.0,
            center_y - extents.height / 2.0,
            foreground,
          )
        end
      end

      context.arc(
        center_x,
        center_y,
        item.max_radius + 1,
        0,
        2 * Math::PI,
      )
      set_color(context, border_color)
      context.stroke
    end

    def size_layout(item)
      create_pango_layout(nil).then do |layout|
        layout.set_markup("<span size=\"small\">#{Formatters.escape_markup(Formatters.format_size(item.results.size))}</span>")
        layout.indent = 0
        layout.spacing = 0
        [layout, layout.pixel_extents.last]
      end
    end

    def draw_sector(context, item, highlighted)
      (item.start_angle + item.angle).then do |final_angle|
        context.arc(
          center_x,
          center_y,
          item.min_radius,
          item.start_angle,
          final_angle,
        )
        context.arc_negative(
          center_x,
          center_y,
          item.max_radius,
          final_angle,
          item.start_angle,
        )
        context.close_path

        set_color(context, sector_color(item, highlighted))
        context.fill_preserve
        set_color(context, background_color)
        context.stroke

        if item.continued?
          draw_continued_edge(context, item, final_angle)
        end
      end
    end

    def sector_color(item, highlighted)
      item_color(item.start_angle / Math::PI * 99, item.depth, highlighted)
    end

    def draw_continued_edge(context, item, final_angle)
      set_color(context, border_color)
      context.set_line_width(3)
      context.arc(
        center_x,
        center_y,
        item.max_radius + 4,
        item.start_angle + EDGE_ANGLE,
        final_angle - EDGE_ANGLE,
      )
      context.stroke
    end

    # Upstream's subtips_update: redraw without the tips, then arm the timeout
    # that brings them back for the newly highlighted sector.
    def subtips_update
      if @drawing_subtips
        queue_draw
      end

      @drawing_subtips = false
      cancel_subtip_timeout
      @subtip_items = []

      unless highlighted_item.nil?
        arm_subtip_timeout
      end
    end

    def cancel_subtip_timeout
      unless @tips_timeout_id.nil?
        GLib::Source.remove(@tips_timeout_id)
        @tips_timeout_id = nil
      end
    end

    def arm_subtip_timeout
      @tips_timeout_id = GLib::Timeout.add(SUBTIP_TIMEOUT) do
        @drawing_subtips = true
        @tips_timeout_id = nil
        queue_draw
        false
      end
    end

    # Upstream collects the highlighted sector's children while drawing.
    def collect_subtip(item)
      if @drawing_subtips && !highlighted_item.nil? && item.parent == highlighted_item
        @subtip_items << item
      end
    end

    # Upstream's post_draw body: one small label per child of the highlighted
    # sector, placed out along the sector's middle angle, joined to the sector
    # by a hairline, and skipped where it would overlap the previous one.
    def draw_subtips(context)
      @subtip_items.inject(
        Gdk::Rectangle.new(
          0,
          0,
          0,
          0,
        ),
      ) do |last_rect, item|
        subtip_geometry(item).then do |layout, rect|
          case
          when rect.intersect(last_rect).nil? then draw_subtip(
            context,
            item,
            layout,
            rect,
          ) && rect
          else last_rect
          end
        end
      end
    end

    def subtip_geometry(item)
      subtip_layout(item).then do |layout, extents|
        [layout, subtip_rect(item, extents)]
      end
    end

    def subtip_layout(item)
      create_pango_layout(nil).then do |layout|
        layout.set_markup("<span size=\"small\">#{Formatters.escape_markup(item.results.display_name)}</span>")
        layout.indent = 0
        layout.spacing = 0
        layout.width = Pango::SCALE * (width / 4)
        layout.ellipsize = :end
        [layout, layout.pixel_extents.last]
      end
    end

    # The tooltip is positioned in the first quadrant and then mirrored into
    # the quadrant the sector's middle angle actually falls in, which is how
    # upstream keeps the trigonometry to one case.
    def subtip_rect(item, extents)
      middle_angle(item).then do |angle|
        first_quadrant_offset(angle, extents).then do |offset_x, offset_y|
          mirror(
            Gdk::Rectangle.new(
              (center_x + offset_x - extents.width / 2.0 - SUBTIP_HPADDING).floor,
              (center_y + offset_y - extents.height / 2.0 - SUBTIP_PADDING).floor,
              (extents.width + SUBTIP_HPADDING * 2).to_i,
              (extents.height + SUBTIP_PADDING * 2).to_i,
            ),
            angle,
          )
        end
      end
    end

    def middle_angle(item) = item.start_angle + item.angle / 2

    def normalize_to_first_quadrant(angle)
      Enumerator
        .produce(angle) { |value| value - Math::PI }
        .find { |value| value <= Math::PI / 2 }
        .abs
    end

    def first_quadrant_offset(angle, extents)
      normalize_to_first_quadrant(angle).then do |normalized|
        quadrant_angle.then do |corner|
          case
          when normalized < corner then horizontal_offset(normalized, extents)
          else vertical_offset(normalized, extents)
          end
        end
      end
    end

    def quadrant_angle = Math.atan2(height / 2.0, width / 2.0)

    def horizontal_offset(angle, extents)
      (width / 2.0 - extents.width / 2.0 - SUBTIP_HPADDING * 2).then do |offset_x|
        [offset_x, Math.tan(angle) * offset_x]
      end
    end

    def vertical_offset(angle, extents)
      (height / 2.0 - extents.height / 2.0 - SUBTIP_PADDING * 2).then do |offset_y|
        [offset_y / Math.tan(angle), offset_y]
      end
    end

    # Upstream flips the rectangle once per quadrant the middle angle is past.
    def mirror(rect, angle)
      quadrants_past(angle).times.inject(rect) do |mirrored, index|
        case index.even?
        when true then Gdk::Rectangle.new(
          width - mirrored.x - mirrored.width,
          mirrored.y,
          mirrored.width,
          mirrored.height,
        )
        else Gdk::Rectangle.new(
          mirrored.x,
          height - mirrored.y - mirrored.height,
          mirrored.width,
          mirrored.height,
        )
        end
      end
    end

    def quadrants_past(angle)
      Enumerator
        .produce([angle, 0]) { |value, count| [value - Math::PI / 2, count + 1] }
        .find { |value, _| value <= Math::PI / 2 }
        .last
    end

    def draw_subtip(context, item, layout, rect)
      draw_subtip_line(context, item, rect)
      draw_subtip_box(context, rect)
      draw_layout(
        context,
        layout,
        rect.x + SUBTIP_HPADDING,
        rect.y + SUBTIP_PADDING,
        subtip_foreground,
      )
      true
    end

    # The line runs from the middle of the sector to the middle of the box, and
    # is clipped out of the box itself so a translucent box stays clean.
    def draw_subtip_line(context, item, rect)
      context.save
      context.rectangle(
        0,
        0,
        width,
        height,
      )
      context.rectangle(
        rect.x + rect.width,
        rect.y,
        -rect.width,
        rect.height,
      )
      context.clip

      sector_center(item).then do |x, y|
        context.set_line_width(1)
        set_color(context, subtip_background)
        context.move_to(x, y)
        context.line_to(rect.x + rect.width / 2.0, rect.y + rect.height / 2.0)
        context.stroke
        context.restore

        context.arc(
          x,
          y,
          1.0,
          0,
          2 * Math::PI,
        )
        context.stroke
      end
    end

    def sector_center(item)
      middle_angle(item).then do |angle|
        (item.min_radius + (item.max_radius - item.min_radius) / 2).then do |radius|
          [center_x + radius * Math.cos(angle), center_y + radius * Math.sin(angle)]
        end
      end
    end

    def draw_subtip_box(context, rect)
      rounded_rectangle(
        context,
        rect.x,
        rect.y,
        rect.width,
        rect.height,
        SUBTIP_RADIUS,
      )
      set_color(context, subtip_background)
      context.fill
    end

    def rounded_rectangle(context, x, y, box_width, box_height, radius)
      context.new_sub_path
      context.arc(
        x + box_width - radius,
        y + radius,
        radius,
        -Math::PI / 2,
        0,
      )
      context.arc(
        x + box_width - radius,
        y + box_height - radius,
        radius,
        0,
        Math::PI / 2,
      )
      context.arc(
        x + radius,
        y + box_height - radius,
        radius,
        Math::PI / 2,
        Math::PI,
      )
      context.arc(
        x + radius,
        y + radius,
        radius,
        Math::PI,
        3 * Math::PI / 2,
      )
      context.close_path
    end

    # Upstream's get_item_rectangle walks the four corners of the sector and
    # then pushes the bounds out at every axis the sector crosses.
    def bounds(item)
      corner_bounds(item).then do |left, top, right, bottom|
        [
          axis_crossed?(item, Math::PI) ? [left, center_x - item.max_radius].min : left,
          axis_crossed?(item, Math::PI * 1.5) ? [top, center_y - item.max_radius].min : top,
          axis_crossed?(item, Math::PI * 2) ? [right, center_x + item.max_radius].max : right,
          axis_crossed?(item, Math::PI / 2) ? [bottom, center_y + item.max_radius].max : bottom,
        ]
      end
    end

    def corner_bounds(item)
      corners(item).inject([width.to_f, height.to_f, 0.0, 0.0]) do |(left, top, right, bottom), (x, y)|
        [[left, x].min, [top, y].min, [right, x].max, [bottom, y].max]
      end
    end

    def corners(item)
      [item.min_radius, item.max_radius].product([item.start_angle, item.start_angle + item.angle])
                                        .map { |radius, angle| point_on(radius, angle) }
    end

    def point_on(radius, angle)
      [center_x + Math.cos(angle) * radius, center_y + Math.sin(angle) * radius]
    end

    def axis_crossed?(item, axis)
      item.start_angle <= axis && item.start_angle + item.angle >= axis
    end

    def draw_layout(context, layout, x, y, color)
      set_color(context, color)
      context.move_to(x, y)
      context.show_pango_layout(layout)
    end

    def set_color(context, rgba)
      context.set_source_rgba(
        rgba.red,
        rgba.green,
        rgba.blue,
        rgba.alpha,
      )
    end

    def foreground = color
    def subtip_foreground = Gdk::RGBA.parse('#ffffff')
    def subtip_background = Gdk::RGBA.new(
      0.0,
      0.0,
      0.0,
      0.8,
    )
    def border_color = Gdk::RGBA.new(
      foreground.red,
      foreground.green,
      foreground.blue,
      0.3,
    )

    # The ring outlines are drawn in the window background so the sectors read
    # as separated, which is what upstream's theme_bg_color lookup gives it.
    def background_color
      style_context.lookup_color('theme_bg_color').then do |found, rgba|
        found ? rgba : Gdk::RGBA.new(
          1.0 - foreground.red,
          1.0 - foreground.green,
          1.0 - foreground.blue,
          1.0,
        )
      end
    end
end
