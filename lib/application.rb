# frozen_string_literal: true

require 'adwaita'
require 'optparse'

require_relative 'about_dialog'
require_relative 'location'
require_relative 'primary_menu'
require_relative 'scanner'
require_relative 'settings'
require_relative 'shortcuts_dialog'
require_relative 'style'
require_relative 'translations'
require_relative 'window'

# Application is the port's entry point: one window, the stylesheet, the
# application actions and the keyboard accelerators.
#
# Ported from upstream's src/main.vala and src/baobab-application.vala. The
# option entries, the HANDLES_OPEN flag, the accelerators set in startup and
# the excluded-locations lookup the scanner uses are all upstream's.
#
# Adwaita::Application is broken in the Ruby bindings, so the application
# object is a Gtk::Application; Adwaita is initialised explicitly, which is
# what Adw.Application's startup would otherwise do. Upstream parses its
# options through GLib's option entries; the Ruby bindings make that awkward
# enough that the same options are parsed with OptionParser before the
# application runs.
#
class Application
  APP_ID = 'org.gnome.baobab'

  # Upstream's set_accels_for_action calls in startup.
  ACCELS = {
    'win.show-preferences'  => ['<Primary>comma'],
    'win.show-primary-menu' => ['F10'],
    'win.scan-folder'       => ['<Primary>o'],
    'win.reload'            => ['<Primary>r'],
    'win.help'              => ['F1'],
    'app.quit'              => ['<Primary>q'],
    'app.shortcuts'         => ['<Primary>question'],
  }.freeze

  def initialize(argv: ARGV, app_id: APP_ID)
    @app_id = app_id
    @options = parse(argv)
  end

  # Returns self rather than the Gtk::Application, so the launcher's `run` is
  # this class's — the one that answers --version without opening a window —
  # rather than Gio::Application's.
  def build
    tap do |port|
      port.app.signal_connect('startup') { start_up }
      port.app.signal_connect('activate') { activate }

      install_actions
    end
  end

  # The options were parsed before GTK saw them, so the application itself is
  # run with an empty argument list.
  def run
    case
    when @options[:version] then print_version
    else app.run([])
    end
  end

  def app = @app ||= Gtk::Application.new(@app_id, :handles_open)
  def settings = @settings ||= Settings.new
  def style = @style ||= Style.new

  def window
    @window ||= Window.new(app, settings).tap { |win| win.build }
  end

  def actions
    @actions ||= {
      'quit'      => Gio::SimpleAction.new('quit'),
      'shortcuts' => Gio::SimpleAction.new('shortcuts'),
    }
  end

  # Upstream's get_excluded_locations, read by every scanner it creates.
  def excluded_locations = settings.excluded_uris

  private

    def parse(argv)
      { all_file_systems: false, version: false, directory: nil }.tap do |options|
        parser(options).parse(argv.dup).then do |rest|
          options[:directory] = rest.first
        end
      end
    end

    def parser(options)
      OptionParser.new do |parser|
        parser.banner = "Usage: baobab [OPTION…] [DIRECTORY]\n\n"
        parser.on('-a', '--all-file-systems', all_file_systems_help) { options[:all_file_systems] = true }
        parser.on('-v', '--version', 'Print version information and exit') { options[:version] = true }
      end
    end

    def all_file_systems_help
      Translations.gettext(
        'Do not skip directories on different file systems. ' \
        'Ignored if DIRECTORY is not specified.',
      )
    end

    def print_version
      puts "#{Translations.gettext('Disk Usage Analyzer')} #{AboutDialog::VERSION}"
      0
    end

    def start_up
      Adwaita.init
      style.install
      Location.excluded_locations_provider = -> { excluded_locations }
      install_accels
    end

    def install_accels
      ACCELS.each { |action, accels| app.set_accels_for_action(action, accels) }
    end

    def install_actions
      actions.each do |name, action|
        action.signal_connect('activate') { activate_action_named(name) }
        app.add_action(action)
      end
    end

    def activate_action_named(name)
      case name
      when 'quit' then app.quit
      else show_shortcuts
      end
    end

    def show_shortcuts
      ShortcutsDialog.new.build.present(window)
    end

    # Upstream's activate, plus its open: a directory on the command line is
    # scanned straight away, with the mount-crossing flag the options chose.
    def activate
      window.tap do |win|
        win.menu_button.menu_model = PrimaryMenu.new.build
        win.present
        scan_requested_directory(win)
      end
    end

    def scan_requested_directory(win)
      @options[:directory].then do |path|
        unless path.nil?
          win.scan_directory(Gio::File.new_for_commandline_arg(path), scan_flags)
        end
      end
    end

    def scan_flags
      @options[:all_file_systems] ? Scanner::NONE : Scanner::EXCLUDE_MOUNTS
    end
end
