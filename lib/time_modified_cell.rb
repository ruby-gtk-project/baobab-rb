# frozen_string_literal: true

require 'adwaita'

require_relative 'formatters'

# TimeModifiedCell shows how long ago a node was last modified.
#
# Ported from upstream's src/baobab-time-modified-cell.vala and
# data/ui/baobab-time-modified-cell.ui: an end-aligned single-line label whose
# text comes from format_time_approximate_cb — blank while the item is unset,
# and the approximate age otherwise.
#
class TimeModifiedCell < Adwaita::Bin
  attr_reader :item

  def initialize
    super
    @item = nil
    build
  end

  def build
    tap do |cell|
      cell.child = label
    end
  end

  def item=(value)
    @item = value
    label.label = format_time
    value
  end

  def label
    @label ||= Gtk::Label.new.tap do |l|
      l.halign = :end
      l.single_line_mode = true
      l.xalign = 1
    end
  end

  private

    def format_time
      item.nil? ? '' : Formatters.format_time_approximate(item.time_modified)
    end
end
