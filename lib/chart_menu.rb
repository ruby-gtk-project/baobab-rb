# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

# ChartMenu is the context menu of the rings and treemap charts.
#
# Ported from upstream's chartmenu in data/gtk/menus.ui: three sections — the
# file actions, going to the parent folder, and the two zoom actions — all on
# the chart's own action group.
#
class ChartMenu
  SECTIONS = [
    [
      ['_Open Externally', 'chart.open-file'],
      ['_Copy Path to Clipboard', 'chart.copy-path'],
      ['Mo_ve to Trash', 'chart.trash-file'],
    ],
    [
      ['Go to _Parent Folder', 'chart.move-up'],
    ],
    [
      ['Zoom _In', 'chart.zoom-in'],
      ['Zoom _Out', 'chart.zoom-out'],
    ],
  ].freeze

  def build
    menu.tap do |model|
      SECTIONS.each { |items| model.append_section(nil, section(items)) }
    end
  end

  def menu = @menu ||= Gio::Menu.new

  private

    def section(items)
      Gio::Menu.new.tap do |model|
        items.each { |label, action| model.append(Translations.gettext(label), action) }
      end
    end
end
