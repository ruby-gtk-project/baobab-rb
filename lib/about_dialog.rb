# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

# AboutDialog is the about window.
#
# Ported from upstream's on_about_activate in src/baobab-window.vala: the same
# application name, icon, developers, copyright, licence, website and issue
# tracker upstream fills an Adw.AboutDialog with.
#
class AboutDialog < Adwaita::AboutDialog
  DEVELOPERS = [
    'Ryan Lortie <desrt@desrt.ca>',
    'Fabio Marzocca <thesaltydog@gmail.com>',
    'Paolo Borelli <pborelli@gnome.com>',
    'Stefano Facchini <stefano.facchini@gmail.com>',
    'Benoît Dejean <benoit@placenet.org>',
    'Igalia (rings-chart and treemap widget) <www.igalia.com>',
  ].freeze

  COPYRIGHT = <<~TEXT
    Copyright © 2005-2011 Fabio Marzocca, Paolo Borelli, Benoît Dejean, Igalia
    Copyright © 2011-2012 Ryan Lortie, Paolo Borelli, Stefano Facchini
  TEXT

  WEBSITE = 'https://apps.gnome.org/Baobab/'
  ISSUE_URL = 'https://gitlab.gnome.org/GNOME/baobab/-/issues/new'

  # Upstream takes this from Config.VERSION, which meson fills in from the
  # project version; this is the upstream release the port is written against.
  VERSION = '48.0'

  def initialize(version = VERSION)
    super()
    @version = version
  end

  def build
    tap do |dialog|
      dialog.application_name = Translations.gettext('Disk Usage Analyzer')
      dialog.application_icon = 'org.gnome.baobab'
      dialog.developer_name = Translations.gettext('The GNOME Project')
      dialog.version = @version
      dialog.website = WEBSITE
      dialog.issue_url = ISSUE_URL
      dialog.copyright = COPYRIGHT
      dialog.license_type = Gtk::License::GPL_2_0
      dialog.developers = DEVELOPERS
      dialog.translator_credits = Translations.gettext('translator-credits')
    end
  end
end
