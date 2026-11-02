# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

# TreeviewMenu is the context menu of the results tree.
#
# Ported from upstream's data/ui/baobab-treeview-menu.ui: one section with
# open, copy path and move to trash, all on the window's action group.
#
class TreeviewMenu
  ITEMS = [
    ['_Open Externally', 'win.treeview-open-folder'],
    ['_Copy Path to Clipboard', 'win.treeview-copy'],
    ['Mo_ve to Trash', 'win.treeview-trash'],
  ].freeze

  def build
    menu.tap do |model|
      model.append_section(nil, section)
    end
  end

  def menu = @menu ||= Gio::Menu.new

  private

    def section
      Gio::Menu.new.tap do |model|
        ITEMS.each { |label, action| model.append(Translations.gettext(label), action) }
      end
    end
end
