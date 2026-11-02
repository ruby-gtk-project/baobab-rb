# frozen_string_literal: true

require 'adwaita'

require_relative 'formatters'
require_relative 'translations'

# LocationRow is one row of the home page: a device or folder with its path and
# how much of it is in use.
#
# Ported from upstream's LocationRow in src/baobab-location-list.vala and
# data/ui/baobab-location-row.ui: a grid with the location's symbolic icon, its
# name in bold, its path below, the available and total sizes on the right, a
# level bar across the bottom, and a go-next arrow at the end of the row.
#
class LocationRow < Gtk::ListBoxRow
  # Upstream turns the level bar's low offset into the critical colour at 90%
  # of the filesystem's size.
  CRITICAL_FRACTION = 0.9

  attr_reader :location

  def initialize(location)
    super()
    @location = location
    build
  end

  def build
    tap do |row|
      row.child = box

      box.tap do |b|
        b.append(grid)
        b.append(next_image)
      end

      grid.tap do |g|
        g.attach(
          image,
          0,
          0,
          1,
          3,
        )
        g.attach(
          name_label,
          1,
          0,
          1,
          1,
        )
        g.attach(
          path_label,
          1,
          1,
          1,
          1,
        )
        g.attach(
          available_label,
          2,
          0,
          1,
          1,
        )
        g.attach(
          total_size_label,
          2,
          1,
          1,
          1,
        )
        g.attach(
          usage_bar,
          1,
          2,
          2,
          1,
        )
      end

      update_location_info
      update_fs_usage_info
      location.on_changed { update_fs_usage_info }
    end
  end

  def box
    @box ||= Gtk::Box.new(:horizontal, 6).tap do |b|
      b.margin_top = 6
      b.margin_bottom = 6
      b.margin_start = 12
      b.margin_end = 6
    end
  end

  def grid = @grid ||= Gtk::Grid.new.tap { |g| g.column_spacing = 12 }

  def image
    @image ||= Gtk::Image.new.tap do |i|
      i.pixel_size = 16
      i.valign = :center
      i.add_css_class('symbolic-circular')
    end
  end

  def name_label
    @name_label ||= Gtk::Label.new.tap do |l|
      l.halign = :start
      l.hexpand = true
      l.valign = :center
      l.vexpand = true
      l.use_markup = true
      l.ellipsize = :end
    end
  end

  def path_label
    @path_label ||= Gtk::Label.new.tap do |l|
      l.halign = :start
      l.hexpand = true
      l.use_markup = true
      l.add_css_class('dim-label')
      l.add_css_class('subtitle')
    end
  end

  def available_label
    @available_label ||= Gtk::Label.new.tap do |l|
      l.halign = :end
      l.valign = :center
      l.vexpand = true
    end
  end

  def total_size_label
    @total_size_label ||= Gtk::Label.new.tap do |l|
      l.halign = :end
      l.add_css_class('dim-label')
      l.add_css_class('subtitle')
    end
  end

  def usage_bar
    @usage_bar ||= Gtk::LevelBar.new.tap do |bar|
      bar.visible = false
      bar.margin_top = 6
      bar.margin_bottom = 6
      bar.hexpand = true
    end
  end

  def next_image
    @next_image ||= Gtk::Image.new.tap do |i|
      i.icon_name = 'go-next-symbolic'
      i.width_request = 32
      i.halign = :end
    end
  end

  private

    def update_location_info
      image.gicon = location.symbolic_icon
      name_label.label = "<b>#{Formatters.escape_markup(location.name)}</b>"
      show_path
    end

    def show_path
      location.file.then do |file|
        path_label.visible = !file.nil?
        unless file.nil?
          path_label.label = Formatters.escape_markup(file.parse_name)
        end
      end

      # For a local mount the end of the path is the interesting part; for a
      # remote one the beginning is.
      if location.remote?
        path_label.ellipsize = :end
      else
        path_label.ellipsize = :start
      end
    end

    # Upstream's update_fs_usage_info.
    def update_fs_usage_info
      total_size_label.visible = false

      if volume_like?
        update_usage_labels
      end
    end

    def volume_like?
      !location.volume.nil? || !location.mount.nil? || location.main_volume?
    end

    def update_usage_labels
      case
      when !location.size.nil? then show_total_and_available
      when !location.used.nil? then show_used_only
      when mountable? then available_label.label = Translations.gettext('Unmounted')
      end
    end

    def mountable?
      !location.volume.nil? && location.mount.nil? && location.volume.can_mount?
    end

    def show_total_and_available
      total_size_label.label = format(Translations.gettext('%s Total'), Formatters.format_size(location.size))
      total_size_label.visible = true

      case location.used
      when nil then available_label.label = Translations.gettext('Unknown')
      else show_available
      end
    end

    def show_available
      actually_used.then do |used|
        available_label.label = format(
          Translations.gettext('%s Available'),
          Formatters.format_size(location.size - used),
        )
        fill_usage_bar(used)
      end
    end

    # Useful for remote mounts where the size is unknown but the usage is not.
    def show_used_only
      available_label.label = format(Translations.gettext('%s Used'), Formatters.format_size(location.used))
    end

    def actually_used = location.used + (location.reserved || 0)

    def fill_usage_bar(used)
      usage_bar.tap do |bar|
        bar.max_value = location.size
        bar.add_offset_value(Gtk::LevelBar::OFFSET_LOW, CRITICAL_FRACTION * location.size)
        bar.value = used
        bar.visible = true
      end
    end
end
