# frozen_string_literal: true

require 'adwaita'

# ProgressCell draws a horizontal bar filled to a fraction, with the
# percentage printed over it in two colours: the plain label where the bar is
# empty and the on-accent label where it is filled.
#
# Ported from upstream's src/baobab-progress-cell.vala, which is itself a
# reimplementation of Sysprof's progress cell. Upstream builds the cell from
# four child widgets (a trough, a progress fill and two labels) and overrides
# measure, size_allocate and snapshot to place and clip them.
#
# The Ruby bindings cannot override a Gtk.Widget vfunc, so the same four pieces
# are drawn into a Gtk::DrawingArea instead: the trough and the fill as rounded
# rectangles, the text twice, with the second pass clipped to the filled part
# exactly as upstream clips its alt label. The colours and the rounding come
# from the same style classes upstream's CSS targets.
#
class ProgressCell < Gtk::DrawingArea
  RADIUS = 5
  MIN_HEIGHT = 18
  WIDTH_CHARS = 7
  TEXT_PADDING = 3

  attr_reader :fraction

  def initialize
    super
    @fraction = 0.0
    build
  end

  def build
    tap do |cell|
      cell.add_css_class('progresscell')
      cell.content_height = MIN_HEIGHT
      cell.content_width = text_width
      cell.valign = :center
      cell.set_draw_func { |_, context, width, height| draw(context, width, height) }
    end
  end

  # Upstream clamps the fraction and queues a redraw only when it changed.
  def fraction=(value)
    value.to_f.clamp(0.0, 1.0).then do |clamped|
      unless @fraction == clamped
        @fraction = clamped
        queue_draw
      end
    end

    value
  end

  # Upstream's update_text, as the string the two labels share.
  def text = format('%6.2f%%', fraction * 100.0)

  private

    def draw(context, width, height)
      draw_trough(context, width, height)
      draw_text(
        context,
        width,
        height,
        trough_text_color,
      )
      draw_fill(context, width, height)
      draw_filled_text(context, width, height)
    end

    def draw_trough(context, width, height)
      rounded_rectangle(
        context,
        0,
        0,
        width,
        height,
      )
      set_color(context, trough_color)
      context.fill
    end

    def draw_fill(context, width, height)
      fill_width(width).then do |filled|
        if filled.positive?
          context.save
          context.rectangle(
            0,
            0,
            filled,
            height,
          )
          context.clip
          rounded_rectangle(
            context,
            0,
            0,
            width,
            height,
          )
          set_color(context, accent_color)
          context.fill
          context.restore
        end
      end
    end

    def draw_filled_text(context, width, height)
      fill_width(width).then do |filled|
        if filled.positive?
          context.save
          context.rectangle(
            0,
            0,
            filled,
            height,
          )
          context.clip
          draw_text(
            context,
            width,
            height,
            accent_text_color,
          )
          context.restore
        end
      end
    end

    def draw_text(context, width, height, color)
      layout.then do |text_layout|
        text_layout.set_text(text)
        text_layout.pixel_extents.last.then do |extents|
          set_color(context, color)
          context.move_to(width - extents.width - TEXT_PADDING, (height - extents.height) / 2.0)
          context.show_pango_layout(text_layout)
        end
      end
    end

    def fill_width(width) = (width * fraction).floor

    def rounded_rectangle(context, x, y, width, height)
      [RADIUS, width / 2.0, height / 2.0].min.then do |radius|
        context.new_sub_path
        context.arc(
          x + width - radius,
          y + radius,
          radius,
          -Math::PI / 2,
          0,
        )
        context.arc(
          x + width - radius,
          y + height - radius,
          radius,
          0,
          Math::PI / 2,
        )
        context.arc(
          x + radius,
          y + height - radius,
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
    end

    def set_color(context, color)
      context.set_source_rgba(
        color.red,
        color.green,
        color.blue,
        color.alpha,
      )
    end

    # The colours upstream's CSS pulls from the Adwaita variables. Current
    # Adwaita publishes them as CSS variables rather than the named colours
    # Gtk::StyleContext#lookup_color can resolve, so the lookup is tried first
    # and the Adwaita defaults — the same values upstream's chart hardcodes —
    # stand behind it.
    def accent_color = style_color('accent_bg_color', '#3584e4')
    def accent_text_color = style_color('accent_fg_color', '#ffffff')

    # The trough text is the widget's own foreground, which is what upstream's
    # unstyled label renders in.
    def trough_text_color = color

    def trough_color
      style_color('borders', '#9a9996').then do |border|
        Gdk::RGBA.new(
          border.red,
          border.green,
          border.blue,
          0.4,
        )
      end
    end

    # Gtk::StyleContext#lookup_color answers with a found flag and the colour.
    def style_color(name, fallback)
      style_context.lookup_color(name).then do |found, rgba|
        found ? rgba : Gdk::RGBA.parse(fallback)
      end
    end

    def layout = @layout ||= create_pango_layout(nil).tap { |l| l.width = Pango::SCALE * text_width }

    # Upstream reserves seven characters for the percentage.
    def text_width
      create_pango_layout('100.00%').pixel_extents.last.width + TEXT_PADDING * 2
    end
end
