# frozen_string_literal: true

require 'adwaita'

require_relative 'location'
require_relative 'location_row'
require_relative 'translations'

# LocationList is the home page: the device and folders on this machine, any
# remote locations, and the folders scanned recently.
#
# Ported from upstream's LocationList in src/baobab-location-list.vala and
# data/ui/baobab-location-list.ui: an Adw.PreferencesPage with a "This Device"
# group and a "Remote Locations" group, each holding a boxed list, kept in step
# with GIO's volume monitor and with Gtk.RecentManager.
#
class LocationList < Adwaita::PreferencesPage
  # Upstream's MAX_RECENT_LOCATIONS.
  MAX_RECENT_LOCATIONS = 5

  # Upstream re-queries filesystem usage every two seconds.
  USAGE_INTERVAL = 2

  # Upstream tags its recent entries with a "baobab" group and filters on it.
  # Gtk::RecentData's groups field cannot be written through the Ruby bindings,
  # so the entries are tagged by application name — which add_full does set —
  # and filtered on that instead.
  RECENT_APP = 'baobab-rb'

  def initialize
    super
    @locations = []
    @location_activated_callbacks = []
    build
  end

  def build
    tap do |page|
      page.add(local_group)
      page.add(remote_group)

      local_group.tap { |group| group.add(local_list_box) }
      remote_group.tap { |group| group.add(remote_list_box) }

      [local_list_box, remote_list_box].each do |list_box|
        list_box.signal_connect('row-activated') { |_, row| location_activated(row.location) }
      end

      watch_volume_monitor
      populate
      start_usage_polling
    end
  end

  # Upstream's location_activated signal.
  def on_location_activated(&block)
    @location_activated_callbacks << block
    block
  end

  # Upstream's update (): rebuild both lists from the locations collected so
  # far, hiding the remote group when there is nothing remote.
  def update
    [local_list_box, remote_list_box].each { |list_box| clear(list_box) }
    remote_group.visible = false

    @locations.each { |location| append_row(location) }
  end

  # Upstream's add_location, which touches the recent entry for a location
  # about to be scanned and reloads the recent list from it.
  def add_location(location)
    unless location.file.nil?
      remember_recently_scanned(location)
      clear_recent(remove_from_recent_manager: false)
      populate_recent
      update
    end
  end

  # Upstream's clear_recent, behind the win.clear-recent action.
  def clear_recent(remove_from_recent_manager: true)
    @locations.select(&:recent?).each do |location|
      if remove_from_recent_manager
        forget_recent(location)
      end

      @locations.delete(location)
    end

    update
  end

  def local_group
    @local_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = Translations.gettext('This Device')
    end
  end

  def remote_group
    @remote_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = Translations.gettext('Remote Locations')
    end
  end

  def local_list_box = @local_list_box ||= boxed_list
  def remote_list_box = @remote_list_box ||= boxed_list
  def volume_monitor = @volume_monitor ||= Gio::VolumeMonitor.get
  def recent_manager = Gtk::RecentManager.default

  private

    def boxed_list
      Gtk::ListBox.new.tap do |list_box|
        list_box.selection_mode = :none
        list_box.add_css_class('boxed-list')
      end
    end

    def location_activated(location)
      @location_activated_callbacks.dup.each { |callback| callback.call(location) }
    end

    def append_row(location)
      LocationRow.new(location).then do |row|
        if location.remote?
          remote_list_box.append(row)
          remote_group.visible = true
        else
          local_list_box.append(row)
        end
      end
    end

    # Upstream empties a list box by repeatedly removing its first child; a
    # lazily produced enumerator cannot stand in for that loop, because the
    # sequence only advances once a child has actually been removed.
    def clear(list_box)
      while list_box.first_child
        list_box.remove(list_box.first_child)
      end
    end

    def watch_volume_monitor
      volume_monitor.tap do |monitor|
        monitor.signal_connect('mount-added') { |_, mount| mount_added(mount) }
        monitor.signal_connect('mount-removed') { |_, mount| mount_removed(mount) }
        monitor.signal_connect('volume-added') { |_, volume| volume_added(volume) }
        monitor.signal_connect('volume-removed') { |_, volume| volume_removed(volume) }
        monitor.signal_connect('volume-changed') { |_, volume| volume_changed(volume) }
      end
    end

    # Upstream's populate ().
    def populate
      @locations << Location.for_home_folder
      @locations << Location.for_main_volume

      volume_monitor.volumes.each { |volume| volume_added(volume) }
      volume_monitor.mounts.each { |mount| mount_added(mount) }

      populate_recent
      update
    end

    def start_usage_polling
      queue_query_fs_usage
      GLib::Timeout.add_seconds(USAGE_INTERVAL) do
        queue_query_fs_usage
        true
      end
    end

    def queue_query_fs_usage
      @locations.each(&:queue_query_fs_usage)
    end

    def already_present?(file)
      @locations.any? { |location| !location.file.nil? && location.file == file }
    end

    # Upstream's volume_changed, which also drops the duplicate mounts a
    # changed volume can leave behind.
    def volume_changed(volume)
      @locations.select { |location| location.volume == volume }.each(&:update_volume_info)

      volume.get_mount.then do |mount|
        unless mount.nil?
          drop_duplicate_mounts(volume, mount)
          update
        end
      end
    end

    def drop_duplicate_mounts(volume, mount)
      @locations
        .select { |location| same_mount?(location, mount) && location.volume != volume }
        .each { |location| @locations.delete(location) }
    end

    # There can be several GMounts with the same root, so the roots are
    # compared rather than the mounts.
    def same_mount?(location, mount)
      !location.mount.nil? && location.mount.root == mount.root
    end

    def volume_removed(volume)
      @locations.find { |location| location.volume == volume }
                .then { |location| @locations.delete(location) }

      update
    end

    def volume_added(volume)
      @locations << Location.from_volume(volume)
      volume.signal_connect('changed') { volume_changed(volume) }
      update
    end

    def mount_removed(mount)
      mount.volume.then do |volume|
        unless volume.nil?
          volume_changed(volume)
        end
      end

      @locations.find { |location| location.mount == mount && location.volume.nil? }
                .then { |location| @locations.delete(location) }

      update
    end

    def mount_added(mount)
      case mount.volume
      when nil then add_volumeless_mount(mount)
      else volume_changed(mount.volume)
      end

      update
    end

    def add_volumeless_mount(mount)
      unless already_present?(mount.root)
        @locations << Location.from_mount(mount)
      end
    end

    # Upstream's populate_recent: the entries this application recorded that
    # still exist and are not already listed, newest first, capped at five.
    def populate_recent
      recent_manager.items
                    .select { |info| scanned_by_baobab?(info) }
                    .sort_by { |info| -modified_at(info) }
                    .first(MAX_RECENT_LOCATIONS)
                    .each { |info| @locations << Location.for_recent_info(info) }
    end

    # GLib::DateTime exposes no seconds-since-the-epoch accessor in the Ruby
    # bindings, but it does format one.
    def modified_at(info) = info.modified.format('%s').to_i

    def scanned_by_baobab?(info)
      info.has_application?(RECENT_APP) &&
        recent_file_exists?(info) &&
        !already_present?(Gio::File.new_for_uri(info.uri))
    end

    # Upstream calls Gtk.RecentInfo.exists (); the Ruby bindings do not bind
    # it, so a local URI is checked on disk and a remote one is taken on trust,
    # which is what RecentInfo does for anything it cannot stat.
    def recent_file_exists?(info)
      Gio::File.new_for_uri(info.uri).then do |file|
        file.uri_scheme != 'file' || File.exist?(file.path.to_s)
      end
    end

    def remember_recently_scanned(location)
      recent_manager.add_full(location.file.uri, recent_data)
    end

    def recent_data
      Gtk::RecentData.new.tap do |data|
        data.mime_type = 'inode/directory'
        data.app_name = RECENT_APP
        data.app_exec = "#{GLib.prgname} %u"
      end
    end

    def forget_recent(location)
      recent_manager.remove_item(location.file.uri)
    rescue StandardError, GLib::Error => e
      warn "Attempting to remove an item from recent locations, but failed: #{e.message}"
    end
end
