# frozen_string_literal: true

require 'adwaita'

require_relative 'formatters'
require_relative 'scanner'

# ContentsCell shows how many files and folders a node contains.
#
# Ported from upstream's src/baobab-contents-cell.vala and
# data/ui/baobab-contents-cell.ui: an end-aligned single-line label with the
# numeric style class, whose text comes from format_items_cb — blank while the
# item is unset, errored or counted as negative, and the item count otherwise.
#
class ContentsCell < Adwaita::Bin
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
    label.label = format_items
    value
  end

  def label
    @label ||= Gtk::Label.new.tap do |l|
      l.halign = :end
      l.single_line_mode = true
      l.xalign = 1
      l.add_css_class('numeric')
    end
  end

  private

    # Upstream's format_items_cb.
    def format_items
      case
      when item.nil? || item.elements.negative? || item.state == Scanner::ERROR then ''
      else Formatters.format_items(item.elements)
      end
    end
end
