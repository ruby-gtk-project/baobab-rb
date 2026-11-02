# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

# PrimaryMenu is the model behind the hamburger button on the home page.
#
# Ported from upstream's primarymenu in data/ui/baobab-main-window.ui: two
# sections, the first for scanning and clearing the recent list, the second for
# preferences, shortcuts, help and about.
#
class PrimaryMenu
  SECTIONS = [
    [
      ['Scan Folder…', 'win.scan-folder'],
      ['Clear Recent List', 'win.clear-recent'],
    ],
    [
      ['Preferences', 'win.show-preferences'],
      ['Keyboard _Shortcuts', 'app.shortcuts'],
      ['_Help', 'win.help'],
      ['_About Disk Usage Analyzer', 'win.about'],
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
