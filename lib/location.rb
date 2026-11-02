# frozen_string_literal: true

require 'adwaita'
require 'socket'

require_relative 'scanner'
require_relative 'translations'

# Location is one entry of the home page: the home folder, the computer's main
# volume, a removable or remote volume, a mount, or a recently scanned folder.
#
# Ported from upstream's src/baobab-location.vala. Upstream's named
# constructors (Location.for_home_folder, .from_volume, .from_mount,
# .for_main_volume, .for_recent_info and .for_file) become class methods here,
# and its `changed` and `progress` signals become callback lists, since a
# plain model class registers no GObject signals in this port.
#
# The one deliberate difference is the hostname: upstream asks
# org.freedesktop.hostname1 over the system bus for a pretty hostname, which
# needs a DBus proxy the Ruby bindings do not generate. The same two values
# systemd serves on that interface are read from /etc/machine-info and the
# kernel instead, with upstream's "Computer" fallback behind them.
#
class Location
  # Upstream's remote_schemes list in Location.from_mount.
  REMOTE_SCHEMES = %w[ftp sftp ssh smb google-drive afp].freeze

  # Upstream's FS_ATTRIBUTES.
  FS_ATTRIBUTES = 'filesystem::size,filesystem::used,filesystem::free'

  MACHINE_INFO = '/etc/machine-info'

  attr_reader :name,
    :file,
    :size,
    :used,
    :reserved,
    :icon,
    :symbolic_icon,
    :volume,
    :mount,
    :scanner

  class << self
    # Upstream's Scanner reads the excluded locations from the application
    # singleton. The provider is set once by the application and read whenever
    # a Location builds its scanner, so the setting a user just changed in the
    # preferences dialog applies to the next scan.
    attr_writer :excluded_locations_provider

    def excluded_locations = (@excluded_locations_provider&.call || [])

    def for_home_folder
      new.tap do |location|
        location.adopt_file(Gio::File.new_for_path(Dir.home))
        location.become_home_location
        location.build_scanner(Scanner::EXCLUDE_MOUNTS)
      end
    end

    def from_volume(volume)
      new.tap do |location|
        location.adopt_volume(volume)
        location.update_volume_info
      end
    end

    def from_mount(mount)
      new.tap do |location|
        location.adopt_mount(mount)
        location.fill_from_mount
        location.detect_remote_scheme
      end
    end

    def for_main_volume
      new.tap do |location|
        location.become_main_volume(hostname)
        location.build_scanner(Scanner::EXCLUDE_MOUNTS)
      end
    end

    def for_recent_info(recent_info)
      new.tap do |location|
        location.become_recent(recent_info)
        location.build_scanner(Scanner::EXCLUDE_MOUNTS)
      end
    end

    def for_file(file, flags = Scanner::NONE)
      new.tap do |location|
        location.adopt_file(file)
        location.name = display_name_for(file)
        location.build_scanner(flags)
      end
    end

    def display_name_for(file)
      file.query_info('standard::display-name', :none).display_name
    rescue StandardError, GLib::Error
      File.basename(file.parse_name)
    end

    # The pretty hostname systemd stores in /etc/machine-info, then the
    # kernel's hostname, then upstream's untranslatable-location fallback.
    def hostname
      pretty_hostname || kernel_hostname || Translations.gettext('Computer')
    end

    def pretty_hostname
      File.readlines(MACHINE_INFO, chomp: true)
          .filter_map { |line| line[/\APRETTY_HOSTNAME=(.*)\z/, 1] }
          .map { |value| value.delete_prefix('"').delete_suffix('"') }
          .reject(&:empty?)
          .first
    rescue SystemCallError
      nil
    end

    def kernel_hostname
      Socket.gethostname.then { |value| value.to_s.empty? ? nil : value }
    end
  end

  def initialize
    @name = nil
    @is_main_volume = false
    @is_remote = false
    @is_recent = false
    @querying_fs = false
    @changed_callbacks = []
    @progress_callbacks = []
  end

  attr_writer :name

  def main_volume? = @is_main_volume
  def remote? = @is_remote
  def recent? = @is_recent

  def on_changed(&block)
    @changed_callbacks << block
    block
  end

  def on_progress(&block)
    @progress_callbacks << block
    block
  end

  def disconnect_progress(block)
    @progress_callbacks.delete(block)
  end

  # Upstream's progress signal, emitted by the window on a timer while a scan
  # runs so the folder display can show the growing totals.
  def progress
    @progress_callbacks.dup.each { |callback| callback.call(self) }
  end

  def changed
    @changed_callbacks.dup.each { |callback| callback.call(self) }
  end

  # Upstream's make_this_home_location.
  def become_home_location
    @name = Translations.gettext('Home Folder')
    @icon = Gio::ThemedIcon.new('user-home')
    @symbolic_icon = Gio::ThemedIcon.new('user-home-symbolic')
  end

  def become_main_volume(hostname)
    @name = hostname
    @file = Gio::File.new_for_path('/')
    @icon = Gio::ThemedIcon.new('drive-harddisk-system')
    @symbolic_icon = Gio::ThemedIcon.new('drive-harddisk-system-symbolic')
    @is_main_volume = true
  end

  def become_recent(recent_info)
    @is_recent = true
    @file = Gio::File.new_for_uri(recent_info.uri)
    @name = recent_info.display_name
    @icon = recent_info.gicon
    @symbolic_icon = Gio::ThemedIcon.new('folder-symbolic')
  end

  def adopt_file(file)
    @file = file
  end

  def adopt_volume(volume)
    @volume = volume
  end

  def adopt_mount(mount)
    @mount = mount
  end

  def build_scanner(flags)
    @scanner = Scanner.new(@file, flags, excluded_locations: Location.excluded_locations)
  end

  def detect_remote_scheme
    @is_remote = REMOTE_SCHEMES.include?(@file&.uri_scheme)
  end

  # Upstream's update_volume_info.
  def update_volume_info
    @is_remote = @volume.get_identifier('class') == 'network'

    @volume.get_mount.then do |new_mount|
      case
      when new_mount.nil? then forget_mount
      when !mounted_as?(new_mount) then remount(new_mount)
      end
    end

    changed
  end

  # Upstream's fill_from_mount.
  def fill_from_mount
    @name = @mount.name
    @icon = @mount.icon
    @symbolic_icon = @mount.symbolic_icon
    @file = @mount.root

    if home_folder?
      become_home_location
    end

    build_scanner(Scanner::EXCLUDE_MOUNTS)
  end

  # Upstream's queue_query_fs_usage. Upstream calls the async variant; the
  # Ruby bindings do not generate a usable finish for it, so the synchronous
  # query runs here — it is a statfs, and the querying flag keeps the two
  # second poll from stacking calls on a slow remote mount.
  def queue_query_fs_usage
    unless @querying_fs || @file.nil?
      @querying_fs = true
      query_fs_usage
      @querying_fs = false
    end
  end

  # Upstream's mount_volume, which the window calls before scanning so an
  # unmounted volume gets mounted first. The block is called once the attempt
  # has finished, with the error or nil.
  def mount_volume(parent_window)
    case
    when !@mount.nil? || @volume.nil? then yield(nil)
    when !@volume.can_mount? then yield(nil)
    else start_mount(parent_window) { |error| yield(error) }
    end
  end

  private

    def mounted_as?(new_mount)
      !@mount.nil? && @mount == new_mount
    end

    def remount(new_mount)
      @mount = new_mount
      fill_from_mount
    end

    def forget_mount
      @name = @volume.name
      @icon = @volume.icon
      @symbolic_icon = @volume.symbolic_icon
      @mount = nil
      @file = nil
      @size = nil
      @used = nil
      @scanner = nil
    end

    def home_folder?
      !@file.nil? && @file == Gio::File.new_for_path(Dir.home)
    end

    def query_fs_usage
      @size = nil
      @used = nil
      @reserved = nil

      @file.query_filesystem_info(FS_ATTRIBUTES).then { |info| read_fs_info(info) }
      changed
    rescue StandardError, GLib::Error
      nil
    end

    def read_fs_info(info)
      @size = attribute(info, 'filesystem::size')
      @used = attribute(info, 'filesystem::used')
      @reserved = reserved_from(info)

      # Upstream guards against the uint64 underflow some remote mounts cause,
      # which would otherwise report 18.4 EB free.
      if !@size.nil? && !@used.nil? && @used > @size
        @size = nil
      end
    end

    def reserved_from(info)
      attribute(info, 'filesystem::free').then do |free|
        if @size.nil? || @used.nil? || free.nil?
          nil
        else
          @size - free - @used
        end
      end
    end

    def attribute(info, name)
      info.has_attribute?(name) ? info.get_attribute_uint64(name) : nil
    end

    def start_mount(parent_window)
      @volume.mount(:none, Gtk::MountOperation.new(parent_window)) do |_, result|
        begin
          @volume.mount_finish(result)
          update_volume_info
          yield(nil)
        rescue StandardError, GLib::Error => e
          yield(e)
        end
      end
    end
end
