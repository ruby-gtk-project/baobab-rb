# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

# ShortcutsDialog lists the keyboard shortcuts.
#
# Ported from upstream's data/ui/shortcuts-dialog.ui: an Adw.ShortcutsDialog
# with a General section and a Scanning section. Upstream's items name an
# action and let Adwaita look the accelerator up from the application; the Ruby
# bindings need the accelerator in the constructor, so each item carries both,
# and the accelerators are the ones the application actually binds.
#
class ShortcutsDialog < Adwaita::ShortcutsDialog
  # The msgctxt upstream's strings carry.
  CONTEXT = 'shortcuts dialog'

  SECTIONS = {
    'General'  => [
      ['Show Help', 'F1', 'win.help'],
      ['Open Main Menu', 'F10', 'win.show-primary-menu'],
      ['Quit', '<Primary>q', 'app.quit'],
      ['Show Keyboard Shortcuts', '<Primary>question', 'app.shortcuts'],
      ['Show Preferences', '<Primary>comma', 'win.show-preferences'],
    ],
    'Scanning' => [
      ['Scan Folder', '<Primary>o', 'win.scan-folder'],
      ['Rescan Current Location', '<Primary>r', 'win.reload'],
    ],
  }.freeze

  def initialize
    super
    self.title = Translations.gettext('Keyboard Shortcuts')
  end

  def build
    tap do |dialog|
      SECTIONS.each { |title, items| dialog.add(section(title, items)) }
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = Translations.pgettext(CONTEXT, title)
        items.each { |label, accelerator, action| section.add(item(label, accelerator, action)) }
      end
    end

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8, accelerator: utf8".
    def item(label, accelerator, action)
      Adwaita::ShortcutsItem.new(Translations.pgettext(CONTEXT, label), accelerator).tap do |shortcut|
        shortcut.action_name = action
      end
    end
end
