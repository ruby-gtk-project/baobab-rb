# frozen_string_literal: true

require 'adwaita'

require_relative 'scanner'

# NameCell shows a node's display name, coloured by the state of its subtree.
#
# Ported from upstream's src/baobab-name-cell.vala and
# data/ui/baobab-name-cell.ui: an ellipsizing, start-aligned, single-line label
# bound to the item's display-name, with the baobab-cell-error and
# baobab-cell-warning style classes added from the item's scan state.
#
class NameCell < Adwaita::Bin
  ERROR_CLASS = 'baobab-cell-error'
  WARNING_CLASS = 'baobab-cell-warning'

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

  # Upstream's on_notify_item_cb, plus the label binding the .ui file sets up.
  def item=(value)
    @item = value
    if value.nil?
      label.label = ''
    else
      label.label = value.display_name.to_s
    end
    apply_state_classes
    value
  end

  def label
    @label ||= Gtk::Label.new.tap do |l|
      l.ellipsize = :end
      l.halign = :start
      l.single_line_mode = true
      l.xalign = 0
    end
  end

  private

    def apply_state_classes
      case item&.state
      when Scanner::ERROR then only_class(ERROR_CLASS)
      when Scanner::CHILD_ERROR then only_class(WARNING_CLASS)
      else only_class(nil)
      end
    end

    def only_class(wanted)
      [ERROR_CLASS, WARNING_CLASS].each do |name|
        if name == wanted
          add_css_class(name)
        else
          remove_css_class(name)
        end
      end
    end
end
