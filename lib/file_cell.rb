# frozen_string_literal: true

require 'adwaita'

require_relative 'name_cell'
require_relative 'progress_cell'

# FileCell is a row of the results tree: the expander, the share-of-parent
# bar, and the name.
#
# Ported from upstream's src/baobab-file-cell.vala and
# data/ui/baobab-file-cell.ui: a Gtk.TreeExpander bound to the cell's list row,
# with its expander hidden for items that have no children, wrapping a box with
# the baobab-cell-box style class that holds a ProgressCell bound to the item's
# fraction and a NameCell bound to the item.
#
class FileCell < Adwaita::Bin
  attr_reader :item, :list_row

  def initialize
    super
    @item = nil
    @list_row = nil
    build
  end

  def build
    tap do |cell|
      cell.child = expander

      expander.tap do |e|
        e.child = box
      end

      box.tap do |b|
        b.append(progress_cell)
        b.append(name_cell)
      end
    end
  end

  def item=(value)
    @item = value
    name_cell.item = value
    if value.nil?
      progress_cell.fraction = 0.0
    else
      progress_cell.fraction = value.fraction
    end
    expander.hide_expander = value.nil? || value.empty?
    value
  end

  def list_row=(row)
    @list_row = row
    expander.list_row = row
    row
  end

  def expander = @expander ||= Gtk::TreeExpander.new

  def box
    @box ||= Gtk::Box.new(:horizontal, 0).tap do |b|
      b.hexpand = true
      b.add_css_class('baobab-cell-box')
    end
  end

  def progress_cell = @progress_cell ||= ProgressCell.new
  def name_cell = @name_cell ||= NameCell.new.tap { |cell| cell.hexpand = true }
end
