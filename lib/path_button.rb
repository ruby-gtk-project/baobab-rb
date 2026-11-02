# frozen_string_literal: true

require 'adwaita'

# PathButton is one segment of the pathbar: an optional icon and a name.
#
# Ported from upstream's PathButton in src/baobab-pathbar.vala and
# data/ui/baobab-pathbutton.ui: a Gtk.Button over a box holding an image and a
# label, dimmed for the ancestors and marked current-dir for the directory the
# tree is rooted at.
#
class PathButton < Gtk::Button
  MIN_CHARS = 7

  # Upstream allows the current directory four times the ellipsizing budget of
  # an ancestor, so the folder being looked at keeps its full name.
  CURRENT_DIR_FACTOR = 4

  # Variable width fonts make a label narrower than the reserved character
  # count, so upstream only reserves a width past a 50% tolerance.
  TOLERANCE = 1.5

  def initialize(name, gicon, current_dir)
    super()
    @name = name.to_s
    @gicon = gicon
    @current_dir = current_dir
    build
  end

  def build
    tap do |button|
      button.tooltip_text = @name
      button.child = box

      box.tap do |b|
        b.append(icon)
        b.append(label)
      end

      apply_emphasis
      apply_ellipsizing
    end
  end

  def box = @box ||= Gtk::Box.new(:horizontal, 6)

  def icon
    @icon ||= Gtk::Image.new.tap do |image|
      image.visible = !@gicon.nil?
      unless @gicon.nil?
        image.gicon = @gicon
      end
    end
  end

  def label
    @label ||= Gtk::Label.new.tap do |l|
      l.label = @name
    end
  end

  private

    def apply_emphasis
      if @current_dir
        add_css_class('current-dir')
      else
        icon.add_css_class('dim-label')
        label.add_css_class('dim-label')
      end
    end

    # A label can ellipsize down to a single ellipsis character, which upstream
    # avoids with a minimum width — but only for names long enough to need it,
    # so short names do not reserve space they will not fill.
    def apply_ellipsizing
      if @name.length > min_chars * TOLERANCE
        label.width_chars = min_chars
        label.ellipsize = :middle
      end
    end

    def min_chars = @current_dir ? MIN_CHARS * CURRENT_DIR_FACTOR : MIN_CHARS
end
