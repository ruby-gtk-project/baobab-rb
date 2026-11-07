# frozen_string_literal: true

require 'adwaita'

require_relative 'formatters'
require_relative 'scanner'

# SizeCell shows a node's size.
#
# Ported from upstream's src/baobab-size-cell.vala and
# data/ui/baobab-size-cell.ui: an end-aligned single-line label with the
# numeric style class, whose text comes from format_size_cb — blank while the
# item is unset or errored, and the formatted byte count otherwise.
#
class SizeCell < Adwaita::Bin
  # See FileCell's type_register for why: without it, a cell handed back
  # from C on unbind/teardown can come back as plain Adwaita::Bin, which has
  # no `item=` and crashes the process rather than raising a catchable error.
  type_register

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
    label.label = format_size
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

    # Upstream's format_size_cb.
    def format_size
      case
      when item.nil? || item.state == Scanner::ERROR then ''
      else Formatters.format_size(item.size)
      end
    end
end
