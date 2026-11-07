# frozen_string_literal: true

require 'adwaita'

require_relative 'name_cell'

# FolderCell is the folder display's header cell: the scanned folder's name,
# with an up arrow in front of it when the folder has a parent to go back to.
#
# Ported from upstream's src/baobab-folder-cell.vala and
# data/ui/baobab-folder-cell.ui: a box with the baobab-cell-box style class
# holding a pan-up-symbolic image, visible from upstream's has_parent_cb, and a
# NameCell bound to the same item.
#
class FolderCell < Adwaita::Bin
  # See FileCell's type_register (file_cell.rb) for why: without it, a cell
  # handed back from C on unbind/teardown can come back as plain
  # Adwaita::Bin, which has no `item=` and crashes the process rather than
  # raising a catchable error.
  type_register

  attr_reader :item

  def initialize
    super
    @item = nil
    build
  end

  def build
    tap do |cell|
      cell.child = box

      box.tap do |b|
        b.append(up_image)
        b.append(name_cell)
      end
    end
  end

  def item=(value)
    @item = value
    name_cell.item = value
    up_image.visible = has_parent?
    value
  end

  def box
    @box ||= Gtk::Box.new(:horizontal, 0).tap do |b|
      b.hexpand = true
      b.add_css_class('baobab-cell-box')
    end
  end

  def up_image
    @up_image ||= Gtk::Image.new.tap do |image|
      image.icon_name = 'pan-up-symbolic'
    end
  end

  def name_cell = @name_cell ||= NameCell.new

  private

    # Upstream's has_parent_cb.
    def has_parent? = !item.nil? && !item.parent.nil?
end
