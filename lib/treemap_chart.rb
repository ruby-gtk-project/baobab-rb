# frozen_string_literal: true

require 'adwaita'

require_relative 'chart'
require_relative 'formatters'

# TreemapChartItem is one rectangle of the treemap, with the fractional
# rectangle the layout is computed in.
#
# Ported from upstream's TreemapItem in src/baobab-treemap.vala.
class TreemapChartItem < ChartItem
  attr_accessor :area_x, :area_y, :area_width, :area_height

  def initialize
    super
    @area_x = 0.0
    @area_y = 0.0
    @area_width = 0.0
    @area_height = 0.0
  end
end

# TreemapChart draws the scan as nested rectangles, splitting each folder's
# rectangle among its children and alternating the split direction with depth.
#
# Ported from upstream's src/baobab-treemap.vala: the alternating horizontal
# and vertical slicing, the padding that leaves the parent's border visible,
# the minimum size below which a rectangle is dropped, and the name drawn in
# the middle of a rectangle that has no visible children.
#
class TreemapChart < Chart
  ITEM_BORDER_WIDTH = 1
  ITEM_PADDING = 6
  ITEM_TEXT_PADDING = 3

  ITEM_MIN_WIDTH = 3
  ITEM_MIN_HEIGHT = 3

  def initialize
    super
    @max_visible_depth = 0
    @more_visible_children = false
    add_css_class('treemap')
  end

  def create_chart_item = TreemapChartItem.new

  # Upstream's calculate_item_geometry.
  def calculate_item_geometry(item)
    if item.depth.zero?
      @max_visible_depth = 0
      @more_visible_children = false
    end

    item.visible = false
    slice(item, parent_area(item))
  end

  # Upstream's draw_item.
  def draw_item(context, item, highlighted)
    drawn_size(item).then do |box_width, box_height|
      draw_rectangle(
        context,
        item,
        box_width,
        box_height,
        fill_color(item, highlighted),
      )
    end
  end

  # Upstream's get_item_rectangle.
  def get_item_rectangle(item)
    drawn_size(item).then do |box_width, box_height|
      item.rect = Gdk::Rectangle.new(
        item.area_x.to_i,
        item.area_y.to_i,
        box_width.to_i,
        box_height.to_i,
      )
    end
  end

  # Upstream's is_point_over_item, a plain rectangle hit test.
  def point_over_item?(item, x, y)
    item.rect.then do |rect|
      x >= rect.x && x <= rect.x + rect.width && y >= rect.y && y <= rect.y + rect.height
    end
  end

  def can_zoom_out? = max_depth < MAX_DEPTH && @more_visible_children
  def can_zoom_in? = @max_visible_depth > 1

  private

    def parent_area(item)
      case item.parent
      when nil then root_area
      else [item.parent.area_x, item.parent.area_y, item.parent.area_width, item.parent.area_height]
      end
    end

    # Upstream starts half a padding outside the widget so the root's own
    # border falls off the edge rather than eating a row of pixels.
    def root_area
      [
        -ITEM_PADDING / 2.0,
        -ITEM_PADDING / 2.0,
        width + ITEM_PADDING * 2.0,
        height + ITEM_PADDING * 2.0,
      ]
    end

    def slice(item, area)
      area.then do |area_x, area_y, area_width, area_height|
        if item.depth.odd?
          slice_horizontally(
            item,
            area_x,
            area_y,
            area_width,
            area_height,
          )
        else
          slice_vertically(
            item,
            area_x,
            area_y,
            area_width,
            area_height,
          )
        end
      end

      finish_slice(item)
    end

    def slice_horizontally(item, area_x, area_y, area_width, area_height)
      (area_width - ITEM_PADDING).then do |usable|
        item.area_x = area_x + (item.rel_start * usable / 100) + ITEM_PADDING
        item.area_y = area_y + ITEM_PADDING
        item.area_width = usable * item.rel_size / 100
        item.area_height = area_height - ITEM_PADDING * 3
      end
    end

    def slice_vertically(item, area_x, area_y, area_width, area_height)
      (area_height - ITEM_PADDING).then do |usable|
        item.area_x = area_x + ITEM_PADDING
        item.area_y = area_y + (item.rel_start * usable / 100) + ITEM_PADDING
        item.area_width = area_width - ITEM_PADDING * 3
        item.area_height = usable * item.rel_size / 100
      end
    end

    def finish_slice(item)
      if big_enough?(item)
        snap_to_pixels(item)
        item.visible = true
        mark_parent(item)
        get_item_rectangle(item)
        record_depth(item)
      end
    end

    def big_enough?(item)
      item.area_width - ITEM_PADDING >= ITEM_MIN_WIDTH &&
        item.area_height - ITEM_PADDING >= ITEM_MIN_HEIGHT
    end

    # Half-pixel offsets keep the one pixel borders crisp.
    def snap_to_pixels(item)
      item.area_x = item.area_x.floor + 0.5
      item.area_y = item.area_y.floor + 0.5
      item.area_width = item.area_width.floor
      item.area_height = item.area_height.floor
    end

    def mark_parent(item)
      unless item.parent.nil?
        item.parent.has_visible_children = true
      end
    end

    def record_depth(item)
      if item.depth == max_depth + 1
        @more_visible_children = true
      else
        @max_visible_depth = [@max_visible_depth, item.depth].max
      end
    end

    # The padding is taken off the axis the rectangle was sliced along, so
    # siblings keep a gap between them.
    def drawn_size(item)
      case
      when item.depth.odd? then [item.area_width - ITEM_PADDING, item.area_height]
      else [item.area_width, item.area_height - ITEM_PADDING]
      end
    end

    def fill_color(item, highlighted)
      case
      when item.depth.odd? then item_color(item.area_x / width * 200, item.depth, highlighted)
      else item_color(item.area_y / height * 200, item.depth, highlighted)
      end
    end

    # Upstream's draw_rectangle: the fill inside the border, the border on top,
    # and the name in the middle when there is room for it and no children are
    # covering it.
    def draw_rectangle(context, item, box_width, box_height, color)
      context.set_line_width(ITEM_BORDER_WIDTH)
      context.rectangle(
        item.area_x + ITEM_BORDER_WIDTH,
        item.area_y + ITEM_BORDER_WIDTH,
        box_width - ITEM_BORDER_WIDTH * 2,
        box_height - ITEM_BORDER_WIDTH * 2,
      )
      set_color(context, color)
      context.fill

      draw_border(
        context,
        item,
        box_width,
        box_height,
      )

      unless item.has_visible_children?
        draw_name(
          context,
          item,
          box_width,
          box_height,
        )
      end
    end

    def draw_border(context, item, box_width, box_height)
      context.rectangle(
        item.area_x + 0.5,
        item.area_y + 0.5,
        box_width - 1,
        box_height - 1,
      )
      set_color(context, border_color)
      context.set_line_width(ITEM_BORDER_WIDTH)
      context.stroke
    end

    def draw_name(context, item, box_width, box_height)
      name_layout(item).then do |layout, extents|
        if fits?(extents, box_width, box_height)
          set_color(context, foreground)
          context.move_to(
            item.area_x + box_width / 2.0 - extents.width / 2.0,
            item.area_y + box_height / 2.0 - extents.height / 2.0,
          )
          context.show_pango_layout(layout)
        end
      end
    end

    def fits?(extents, box_width, box_height)
      extents.width + ITEM_TEXT_PADDING * 2 <= box_width &&
        extents.height + ITEM_TEXT_PADDING * 2 <= box_height
    end

    def name_layout(item)
      create_pango_layout(nil).then do |layout|
        layout.set_markup(Formatters.escape_markup(item.results.display_name.to_s))
        [layout, layout.pixel_extents.last]
      end
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
    def border_color = Gdk::RGBA.new(
      foreground.red,
      foreground.green,
      foreground.blue,
      0.3,
    )
end
