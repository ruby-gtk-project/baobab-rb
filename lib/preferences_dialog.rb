# frozen_string_literal: true

require 'adwaita'

require_relative 'excluded_row'
require_relative 'settings'
require_relative 'translations'

# PreferencesDialog is the list of locations left out of a scan.
#
# Ported from upstream's PreferencesDialog in
# src/baobab-preferences-dialog.vala and
# data/ui/baobab-preferences-dialog.ui: an Adw.PreferencesDialog with a
# "Locations to Ignore" group holding a boxed list of the excluded URIs, with an
# Adw.ButtonRow at the bottom that opens a folder chooser.
#
# Upstream reads and writes the org.gnome.baobab.preferences schema directly;
# here the same key comes from the port's Settings.
#
class PreferencesDialog < Adwaita::PreferencesDialog
  CONTENT_HEIGHT = 570

  def initialize(settings)
    super()
    @settings = settings
  end

  def build
    tap do |dialog|
      dialog.title = Translations.gettext('Preferences')
      dialog.content_height = CONTENT_HEIGHT
      dialog.add(page)

      page.tap { |p| p.add(group) }
      group.tap { |g| g.add(excluded_list_box) }

      excluded_list_box.signal_connect('row-activated') { |_, row| row_activated(row) }

      populate
    end
  end

  def page = @page ||= Adwaita::PreferencesPage.new

  def group
    @group ||= Adwaita::PreferencesGroup.new.tap do |g|
      g.title = Translations.gettext('Locations to Ignore')
    end
  end

  def excluded_list_box
    @excluded_list_box ||= Gtk::ListBox.new.tap do |list_box|
      list_box.selection_mode = :none
      list_box.add_css_class('boxed-list')
    end
  end

  def add_button_row
    @add_button_row ||= Adwaita::ButtonRow.new.tap do |row|
      row.title = Translations.gettext('_Add Location')
      row.start_icon_name = 'list-add-symbolic'
      row.use_underline = true
    end
  end

  private

    # The only activatable row is the Add Location button row.
    def row_activated(row)
      if row == add_button_row
        choose_location
      end
    end

    def populate
      clear

      @settings.excluded_uris.each { |uri| excluded_list_box.append(excluded_row(uri)) }
      excluded_list_box.append(add_button_row)
    end

    def excluded_row(uri)
      ExcludedRow.new(Gio::File.new_for_uri(uri)).tap do |row|
        row.on_removed do |removed|
          @settings.remove_excluded_uri(removed.uri)
          populate
        end
      end
    end

    def clear
      while excluded_list_box.first_child
        excluded_list_box.remove(excluded_list_box.first_child)
      end
    end

    # Upstream opens a Gtk.FileChooserNative in SELECT_FOLDER mode, which is
    # also the chooser the window's scan action uses.
    def choose_location
      folder_chooser.tap do |chooser|
        chooser.signal_connect('response') { |_, response| location_chosen(chooser, response) }
        chooser.show
      end
    end

    def folder_chooser
      Gtk::FileChooserNative.new(
        Translations.gettext('Select Location to Ignore'),
        root_window,
        :select_folder,
        nil,
        nil,
      ).tap do |chooser|
        chooser.modal = true
      end
    end

    def location_chosen(chooser, response)
      if response == Gtk::ResponseType::ACCEPT
        @settings.add_excluded_uri(chooser.file.uri)
        populate
      end

      chooser.destroy
    end

    def root_window
      root.is_a?(Gtk::Window) ? root : nil
    end
end
