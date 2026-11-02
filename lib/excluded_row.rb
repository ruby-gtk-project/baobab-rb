# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

# ExcludedRow is one row of the preferences dialog's ignore list.
#
# Ported from upstream's ExcludedRow in src/baobab-preferences-dialog.vala and
# data/ui/baobab-excluded-row.ui: a non-activatable Adw.ActionRow titled with
# the location, and a flat delete button as its suffix.
#
class ExcludedRow < Adwaita::ActionRow
  attr_reader :file

  def initialize(file)
    super()
    @file = file
    @removed_callbacks = []
    build
  end

  def build
    tap do |row|
      row.activatable = false
      row.title = row_title
      row.add_suffix(remove_button)

      remove_button.signal_connect('clicked') { removed }
    end
  end

  def on_removed(&block)
    @removed_callbacks << block
    block
  end

  def remove_button
    @remove_button ||= Gtk::Button.new.tap do |button|
      button.tooltip_text = Translations.gettext('Remove Folder')
      button.valign = :center
      button.icon_name = 'edit-delete-symbolic'
      button.add_css_class('flat')
    end
  end

  def uri = file.uri

  private

    def removed
      @removed_callbacks.dup.each { |callback| callback.call(self) }
    end

    # Upstream shows the path for local files and the URI for everything else.
    def row_title
      file.uri_scheme == 'file' ? file.path.to_s : file.uri
    end
end
