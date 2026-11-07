# frozen_string_literal: true

require 'adwaita'

require_relative 'about_dialog'
require_relative 'contents_cell'
require_relative 'file_cell'
require_relative 'folder_display'
require_relative 'location'
require_relative 'location_list'
require_relative 'pathbar'
require_relative 'preferences_dialog'
require_relative 'rings_chart'
require_relative 'scanner'
require_relative 'settings'
require_relative 'size_cell'
require_relative 'time_modified_cell'
require_relative 'translations'
require_relative 'treemap_chart'
require_relative 'treeview_menu'

# Window is the application window: the home page listing the devices and
# locations, and the results page with the folder tree on the left and a chart
# on the right.
#
# Ported from upstream's src/baobab-window.vala and
# data/ui/baobab-main-window.ui — the navigation view, the toast overlay, the
# allocated-size banner, the pathbar in the results header bar, the overlay
# split view, the column view and its context menu, and the chart stack behind
# the view switcher.
#
# Upstream's window reaches its widgets through a GtkTemplate; here they are
# memoized accessors and `build` assembles them, which is the only structural
# difference. Everything it does — the actions, the drag and drop, the
# geometry saving, the scan lifecycle — is upstream's.
#
class Window < Adwaita::ApplicationWindow
  WIDTH_REQUEST = 294
  HEIGHT_REQUEST = 246
  CHART_PANE_WIDTH_REQUEST = 360
  PATHBAR_WIDTH_REQUEST = 700
  CHART_ACTION_BAR_HEIGHT = 48
  SIDEBAR_FRACTION = 0.5
  MAX_SIDEBAR_WIDTH = 99_999
  NARROW_BREAKPOINT = 'max-width: 500sp'

  # Upstream emits the location's progress signal twice a second while a scan
  # runs so the folder display's totals keep moving.
  PROGRESS_INTERVAL = 500

  SCAN_COMPLETED_NOTIFICATION = 'scan-completed'

  # Upstream's action_entries.
  ACTIONS = %w[
    scan-folder
    reload
    clear-recent
    show-preferences
    help
    about
    show-treeview-popover
    treeview-expand-row
    treeview-collapse-row
    treeview-go-up
    treeview-open-folder
    treeview-copy
    treeview-trash
  ].freeze

  # Upstream's actions_while_scanning: scanning disables starting another scan.
  ACTIONS_WHILE_SCANNING = { 'scan-folder' => false }.freeze

  CHARTS = { 'rings' => 'Rings Chart', 'treemap' => 'Treemap Chart' }.freeze

  COLUMNS = {
    folder:        ['Folder', FileCell],
    size:          ['Size', SizeCell],
    contents:      ['Contents', ContentsCell],
    time_modified: ['Modified', TimeModifiedCell],
  }.freeze

  def initialize(application, settings)
    super(application)
    @settings = settings
    @active_location = nil
    @clicked_item = nil
    @is_busy = false
    @scan_completed_handler = nil
    @progress_id = nil
  end

  def build
    tap do |window|
      window.title = Translations.gettext('Disk Usage Analyzer')
      window.icon_name = 'org.gnome.baobab'
      window.width_request = WIDTH_REQUEST
      window.height_request = HEIGHT_REQUEST
      window.content = toast_overlay

      install_actions
      assemble_home_page
      assemble_result_page

      toast_overlay.tap do |overlay|
        overlay.child = nav_view

        nav_view.tap do |view|
          view.add(home_page)
          view.add(result_page)
          view.add_css_class('contents')
        end
      end

      connect_controllers
      @settings.apply_to(window)
      set_ui_state(home_page, false)
    end
  end

  # Upstream's scan_directory, which the application calls for a command line
  # argument or a dropped folder.
  def scan_directory(directory, flags = Scanner::NONE)
    case
    when directory?(directory) then scan_location(Location.for_file(directory, flags))
    else toast(format(Translations.gettext('“%s” is not a valid folder'), directory.parse_name))
    end
  end

  # Upstream's open_item, copy_path and trash_file, which the charts and the
  # tree context menu both reach.
  def open_item(results)
    Gio::AppInfo.launch_default_for_uri(file_for(results).uri, nil)
  rescue StandardError, GLib::Error => e
    warn "Failed to open file: #{e.message}"
    toast(Translations.gettext('Failed to open file'))
  end

  def copy_path(results)
    clipboard.set(file_for(results).parse_name)
  end

  def trash_file(results)
    if trash(file_for(results))
      drop_from_model(results)
    end
  end

  def toast(title)
    toast_overlay.add_toast(Adwaita::Toast.new(title))
  end

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
  def nav_view = @nav_view ||= Adwaita::NavigationView.new

  def home_page
    @home_page ||= Adwaita::NavigationPage.new(home_toolbar, Translations.gettext('Devices & Locations')).tap do |page|
      page.tag = 'home'
    end
  end

  def result_page
    @result_page ||= Adwaita::NavigationPage.new(result_toolbar, Translations.gettext('Results')).tap do |page|
      page.tag = 'results'
    end
  end

  def home_toolbar = @home_toolbar ||= Adwaita::ToolbarView.new

  def result_toolbar
    @result_toolbar ||= Adwaita::ToolbarView.new.tap do |view|
      view.top_bar_style = :raised
    end
  end

  def home_header_bar = @home_header_bar ||= Adwaita::HeaderBar.new
  def result_header_bar = @result_header_bar ||= Adwaita::HeaderBar.new

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'open-menu-symbolic'
      button.primary = true
      button.tooltip_text = Translations.gettext('Main Menu')
    end
  end

  def reload_button
    @reload_button ||= Gtk::Button.new.tap do |button|
      button.action_name = 'win.reload'
      button.icon_name = 'view-refresh-symbolic'
      button.tooltip_text = Translations.gettext('Rescan Current Location')
    end
  end

  def location_list = @location_list ||= LocationList.new

  def pathbar
    @pathbar ||= Pathbar.new.tap do |bar|
      bar.valign = :center
      bar.width_request = PATHBAR_WIDTH_REQUEST
      bar.add_css_class('pathbar')
    end
  end

  def banner
    @banner ||= Adwaita::Banner.new(Translations.gettext('Files may take more space than shown'))
  end

  def folder_display = @folder_display ||= FolderDisplay.new

  def split_view
    @split_view ||= Adwaita::OverlaySplitView.new.tap do |view|
      view.max_sidebar_width = MAX_SIDEBAR_WIDTH
      view.sidebar_width_fraction = SIDEBAR_FRACTION
    end
  end

  def column_view
    @column_view ||= Gtk::ColumnView.new.tap do |view|
      view.hexpand = true
      view.reorderable = false
      view.single_click_activate = true
    end
  end

  def selection = @selection ||= Gtk::SingleSelection.new(Gio::ListStore.new(Scanner::Results))

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |sw|
      sw.vexpand = true
      sw.hscrollbar_policy = :never
      sw.add_css_class('undershoot-top')
    end
  end

  def treeview_popover_menu
    @treeview_popover_menu ||= Gtk::PopoverMenu.new(TreeviewMenu.new.build).tap do |menu|
      menu.position = :bottom
    end
  end

  def chart_stack = @chart_stack ||= Adwaita::ViewStack.new
  def spinner_stack = @spinner_stack ||= Gtk::Stack.new
  def spinner = @spinner ||= Adwaita::Spinner.new

  def chart_stack_switcher
    @chart_stack_switcher ||= Adwaita::ViewSwitcher.new.tap do |switcher|
      switcher.stack = chart_stack
      switcher.policy = :wide
    end
  end

  def rings_chart = @rings_chart ||= expanding(RingsChart.new)
  def treemap_chart = @treemap_chart ||= expanding(TreemapChart.new)
  def charts = @charts ||= { 'rings' => rings_chart, 'treemap' => treemap_chart }

  def chart_action_bar
    @chart_action_bar ||= Gtk::ActionBar.new.tap do |bar|
      bar.height_request = CHART_ACTION_BAR_HEIGHT
    end
  end

  def chart_toolbar = @chart_toolbar ||= Adwaita::ToolbarView.new

  def breakpoint_bin
    @breakpoint_bin ||= Adwaita::BreakpointBin.new.tap do |bin|
      bin.width_request = CHART_PANE_WIDTH_REQUEST
      bin.height_request = HEIGHT_REQUEST
    end
  end

  def drop_target
    @drop_target ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy)
  end

  def focus_controller = @focus_controller ||= Gtk::EventControllerFocus.new
  def key_controller = @key_controller ||= Gtk::EventControllerKey.new

  def right_click_gesture
    @right_click_gesture ||= Gtk::GestureClick.new.tap do |gesture|
      gesture.button = Gdk::BUTTON_SECONDARY
    end
  end

  def actions
    @actions ||= ACTIONS.to_h { |name| [name, Gio::SimpleAction.new(name)] }
  end

  # Upstream's show-primary-menu action carries the menu button's state.
  def show_primary_menu_action
    @show_primary_menu_action ||= Gio::SimpleAction.new(
      'show-primary-menu',
      nil,
      GLib::Variant.new(false),
    )
  end

  # Upstream binds the ui schema's active-chart key to the chart stack and adds
  # the settings' own action so the view switcher and the menu agree.
  def active_chart_action
    @active_chart_action ||= Gio::SimpleAction.new(
      'active-chart',
      GLib::VariantType.new('s'),
      GLib::Variant.new(@settings.active_chart),
    )
  end

  private

    def expanding(chart)
      chart.tap do |widget|
        widget.hexpand = true
        widget.vexpand = true
      end
    end

    def assemble_home_page
      home_toolbar.tap do |view|
        view.add_top_bar(home_header_bar)
        view.content = location_list
      end

      home_header_bar.tap { |bar| bar.pack_end(menu_button) }
    end

    def assemble_result_page
      result_toolbar.tap do |view|
        view.add_top_bar(result_header_bar)
        view.content = result_content
      end

      result_header_bar.tap do |bar|
        bar.title_widget = pathbar
        bar.pack_end(reload_button)
      end

      assemble_split_view
      assemble_chart_pane
    end

    def result_content
      @result_content ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.append(banner)
        box.append(split_view)
      end
    end

    def assemble_split_view
      split_view.tap do |view|
        view.sidebar = sidebar
        view.content = breakpoint_bin
      end

      sidebar.tap do |box|
        box.append(tree_pane)
        box.append(Gtk::Separator.new(:vertical))
      end

      tree_pane.tap do |box|
        box.append(folder_display)
        box.append(scrolled_window)
      end

      scrolled_window.tap { |sw| sw.child = column_view }
      assemble_column_view
    end

    def sidebar = @sidebar ||= Gtk::Box.new(:horizontal, 0)

    def tree_pane
      @tree_pane ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.hexpand = true
      end
    end

    def assemble_column_view
      column_view.tap do |view|
        view.model = selection
        COLUMNS.each_key { |name| view.append_column(column(name)) }
        view.signal_connect('activate') { |_, position| activate_row(position) }
        view.add_controller(right_click_gesture)
        view.add_controller(key_controller)
      end

      treeview_popover_menu.set_parent(column_view)
      hide_column_view_header
    end

    def columns
      @columns ||= COLUMNS.keys.to_h { |name| [name, build_column(name)] }
    end

    def column(name) = columns.fetch(name)

    def build_column(name)
      COLUMNS.fetch(name).then do |title, cell_class|
        Gtk::ColumnViewColumn.new(Translations.gettext(title), factory(name, cell_class)).tap do |col|
          col.expand = name == :folder
        end
      end
    end

    # Upstream's per-column setup/bind/unbind/teardown callbacks: the cell is
    # added to the folder display's size group for its column so the tree lines
    # up under the header, and the folder column's cell also gets the tree row
    # for its expander.
    def factory(name, cell_class)
      Gtk::SignalListItemFactory.new.tap do |f|
        f.signal_connect('setup') { |_, cell| setup_cell(name, cell_class, cell) }
        f.signal_connect('bind') { |_, cell| bind_cell(cell) }
        f.signal_connect('unbind') { |_, cell| cell.child.item = nil }
        f.signal_connect('teardown') { |_, cell| folder_display.size_group(name).remove_widget(cell.child) }
      end
    end

    def setup_cell(name, cell_class, cell)
      cell_class.new.then do |child|
        cell.child = child
        folder_display.size_group(name).add_widget(child)
      end
    end

    def bind_cell(cell)
      cell.item.then do |row|
        cell.child.item = row.item

        if cell.child.respond_to?(:list_row=)
          cell.child.list_row = row
        end
      end
    end

    def assemble_chart_pane
      breakpoint_bin.tap do |bin|
        bin.child = chart_toolbar
        bin.add_breakpoint(narrow_breakpoint)
      end

      chart_toolbar.tap do |view|
        view.content = spinner_stack
        view.add_bottom_bar(chart_action_bar)
      end

      spinner_stack.tap do |stack|
        stack.add_named(chart_stack, 'charts')
        stack.add_named(spinner, 'spinner')
      end

      chart_stack.tap do |stack|
        CHARTS.each { |name, title| add_chart_page(stack, name, title) }
        stack.visible_child_name = @settings.active_chart
        stack.signal_connect('notify::visible-child-name') { remember_active_chart }
      end

      chart_action_bar.tap { |bar| bar.set_center_widget(chart_stack_switcher) }
    end

    def add_chart_page(stack, name, title)
      stack.add_titled_with_icon(
        charts.fetch(name),
        name,
        Translations.gettext(title),
        "view-#{name.sub('rings', 'ringschart')}-symbolic",
      ).tap do |page|
        page.use_underline = true
      end
    end

    # Upstream's breakpoint uses a setter on the view switcher's policy.
    # Adwaita's setters take a GValue of the property's own type, and the Ruby
    # bindings hand it a string, which Adwaita rejects fatally — so the policy
    # is switched from the breakpoint's own apply and unapply signals instead.
    def narrow_breakpoint
      Adwaita::Breakpoint.new(Adwaita::BreakpointCondition.parse(NARROW_BREAKPOINT)).tap do |breakpoint|
        breakpoint.signal_connect('apply') { chart_stack_switcher.policy = :narrow }
        breakpoint.signal_connect('unapply') { chart_stack_switcher.policy = :wide }
      end
    end

    def install_actions
      actions.each do |name, action|
        action.signal_connect('activate') { activate_window_action(name) }
        add_action(action)
      end

      add_action(show_primary_menu_action)
      show_primary_menu_action.signal_connect('activate') { toggle_primary_menu }
      menu_button.signal_connect('notify::active') { sync_primary_menu_state }

      add_action(active_chart_action)
      active_chart_action.signal_connect('activate') { |_, parameter| self.active_chart = chart_name(parameter) }
    end

    # The gio2 bindings hand the 'activate' signal a plain Ruby String for a
    # string-typed action parameter rather than the GLib::Variant upstream's
    # Vala receives, so get_string is only there to call when one is given.
    def chart_name(parameter)
      parameter.respond_to?(:get_string) ? parameter.get_string : parameter
    end

    def activate_window_action(name)
      case name
      when 'scan-folder' then choose_folder
      when 'reload' then reload
      when 'clear-recent' then location_list.clear_recent
      when 'show-preferences' then show_preferences
      when 'help' then show_help
      when 'about' then show_about
      else activate_treeview_action(name)
      end
    end

    def activate_treeview_action(name)
      case name
      when 'show-treeview-popover' then show_treeview_popover_centred
      when 'treeview-expand-row' then expand_selected_row
      when 'treeview-collapse-row' then collapse_selected_row
      when 'treeview-go-up' then go_up_treeview
      when 'treeview-open-folder' then with_selected_item { |item| open_item(item) }
      when 'treeview-copy' then with_selected_item { |item| copy_path(item) }
      when 'treeview-trash' then with_selected_item { |item| trash_file(item) }
      end
    end

    # Upstream's on_show_primary_menu_activate toggles the action's state; the
    # menu button follows it, and reports back when the user closes the menu.
    def toggle_primary_menu
      (!show_primary_menu_action.state).then do |opened|
        show_primary_menu_action.set_state(GLib::Variant.new(opened))
        menu_button.active = opened
      end
    end

    def sync_primary_menu_state
      unless show_primary_menu_action.state == menu_button.active?
        show_primary_menu_action.set_state(GLib::Variant.new(menu_button.active?))
      end
    end

    def active_chart=(name)
      if CHARTS.key?(name)
        chart_stack.visible_child_name = name
        active_chart_action.set_state(GLib::Variant.new(name))
        @settings['active-chart'] = name
      end

      name
    end

    def remember_active_chart
      chart_stack.visible_child_name.then do |name|
        unless name.nil?
          active_chart_action.set_state(GLib::Variant.new(name))
          @settings['active-chart'] = name
        end
      end
    end

    def connect_controllers
      location_list.on_location_activated { |location| location_activated(location) }
      folder_display.on_activated { go_up_treeview }
      pathbar.on_item_activated { |path| reroot_treeview(path) }

      charts.each_value { |chart| connect_chart(chart) }

      result_page.signal_connect('hidden') { results_hidden }
      right_click_gesture.signal_connect('pressed') { |_, _n, x, y| right_clicked(x, y) }
      key_controller.signal_connect('key-pressed') { |_, keyval, _code, state| key_pressed(keyval, state) }

      connect_drop_target
      connect_focus_controller
      connect_geometry_saving
    end

    def connect_chart(chart)
      chart.on_item_activated { |item| reroot_treeview(item) }
      chart.on_file_action('open-file') { |item| open_item(item) }
      chart.on_file_action('copy-path') { |item| copy_path(item) }
      chart.on_file_action('trash-file') { |item| trash_file(item) }
    end

    def connect_drop_target
      add_controller(drop_target)
      drop_target.signal_connect('accept') { !@is_busy }
      drop_target.signal_connect('drop') { |_, value, _x, _y| dropped(value) }
    end

    def connect_focus_controller
      add_controller(focus_controller)
      focus_controller.signal_connect('enter') do
        application&.withdraw_notification(SCAN_COMPLETED_NOTIFICATION)
      end
    end

    def connect_geometry_saving
      signal_connect('close-request') do
        @settings.remember(self)
        false
      end
    end

    # Upstream's on_drop: a single dropped folder is scanned.
    def dropped(value)
      files_from(value).then do |files|
        case files.length
        when 1 then scan_and_accept(files.first)
        else false
        end
      end
    end

    def files_from(value)
      case value
      when Gdk::FileList then value.files
      when Gio::File then [value]
      else []
      end
    end

    def scan_and_accept(file)
      scan_directory(file)
      true
    end

    # Upstream's results_hidden: leaving the results page cancels the scan.
    def results_hidden
      cancel_scan
      banner.revealed = false
      set_ui_state(home_page, false)
    end

    # Upstream's on_scan_folder_activate: a folder chooser carrying the
    # "Recursively analyze mount points" choice, which decides whether the scan
    # crosses mount points. Gtk::FileChooserNative is the only chooser in these
    # bindings that can carry an extra choice, which is why upstream's
    # deprecated-but-present chooser is the one used here.
    def choose_folder
      folder_chooser.tap do |chooser|
        chooser.signal_connect('response') { |_, response| folder_chosen(chooser, response) }
        chooser.show
      end
    end

    def folder_chooser
      Gtk::FileChooserNative.new(
        Translations.gettext('Select Folder'),
        self,
        :select_folder,
        nil,
        nil,
      ).tap do |chooser|
        chooser.modal = true
        chooser.add_choice(
          'recurse',
          Translations.gettext('Recursively analyze mount points'),
          nil,
          nil,
        )
      end
    end

    def folder_chosen(chooser, response)
      if response == Gtk::ResponseType::ACCEPT
        scan_directory(chooser.file, chosen_scan_flags(chooser))
      end

      chooser.destroy
    end

    def chosen_scan_flags(chooser)
      chooser.get_choice('recurse') == 'true' ? Scanner::NONE : Scanner::EXCLUDE_MOUNTS
    end

    # Upstream's location_activated: mount the volume if it needs mounting,
    # then scan it.
    def location_activated(location)
      set_busy(true)
      location.mount_volume(self) do |error|
        case error
        when nil then scan_location(location)
        else report_mount_failure(error)
        end
      end
    end

    def report_mount_failure(error)
      set_busy(false)
      warn "Could not analyze volume: #{error.message}"
      toast(Translations.gettext('Could not analyze volume'))
    end

    def reload
      unless @active_location.nil?
        scan_location(@active_location, force: true)
      end
    end

    def show_preferences
      PreferencesDialog.new(@settings).build.present(self)
    end

    # Upstream's win.help: open the Mallard help pages ported into help/C
    # under the 'help:baobab' URI, exactly as upstream does. That URI only
    # resolves on a system with yelp (or another help: handler) registered;
    # with none, Gtk.show_uri launches nothing and fails silently, so this
    # falls back to opening the local index page directly.
    def show_help
      if Gio::AppInfo.get_default_for_uri_scheme('help').nil?
        Gtk.show_uri(screen: self, uri: "file://#{local_help_index}", timestamp: Gdk::CURRENT_TIME)
      else
        Gtk.show_uri(screen: self, uri: 'help:baobab', timestamp: Gdk::CURRENT_TIME)
      end
    end

    def local_help_index = File.expand_path('../help/C/index.page', __dir__)

    def show_about
      AboutDialog.new.build.present(self)
    end

    # Upstream's cancel_scan.
    def cancel_scan
      @active_location.then do |location|
        unless location.nil? || location.scanner.nil?
          location.scanner.cancel
          disconnect_scan_handler(location.scanner)
        end
      end

      stop_progress_timer
      @active_location = nil
    end

    def disconnect_scan_handler(scanner)
      unless @scan_completed_handler.nil?
        scanner.disconnect_completed(@scan_completed_handler)
        @scan_completed_handler = nil
      end
    end

    def stop_progress_timer
      unless @progress_id.nil?
        GLib::Source.remove(@progress_id)
        @progress_id = nil
      end
    end

    # Upstream's scan_location.
    def scan_location(location, force: false)
      cancel_scan

      @active_location = location
      pathbar.location = location
      folder_display.location = location
      location_list.add_location(location)
      selection.model = Gio::ListStore.new(Scanner::Results)

      @scan_completed_handler = location.scanner.on_completed { scanner_completed }
      banner.revealed = false
      start_progress_timer(location)
      set_ui_state(result_page, true)
      location.scanner.scan(force)
    end

    def start_progress_timer(location)
      @progress_id = GLib::Timeout.add(PROGRESS_INTERVAL) do
        location.progress
        true
      end
    end

    # Upstream's scanner_completed.
    def scanner_completed
      @active_location.then do |location|
        unless location.nil?
          finish_scan(location.scanner)
        end
      end
    end

    def finish_scan(scanner)
      disconnect_scan_handler(scanner)
      stop_progress_timer

      case scan_outcome(scanner)
      when :cancelled then nil
      when :failed then report_scan_failure(scanner)
      else show_results(scanner)
      end
    end

    def scan_outcome(scanner)
      scanner.finish
      :done
    rescue Scanner::Cancelled
      :cancelled
    rescue StandardError, GLib::Error => e
      @scan_failure = e
      :failed
    end

    def report_scan_failure(scanner)
      warn "Could not scan folder #{scanner.directory.parse_name}: #{@scan_failure&.message}"
      toast(Translations.gettext('Could not scan folder'))
      set_ui_state(home_page, false)
    end

    def show_results(scanner)
      reroot_treeview(scanner.root)
      set_chart_location(@active_location)
      set_ui_state(result_page, false)

      # Upstream refreshes the folder display once more after the scan.
      folder_display.path = scanner.root
      banner.revealed = !scanner.show_allocated_size
      notify_scan_completed(scanner)
    end

    def set_chart_location(location)
      charts.each_value { |chart| chart.location = location }
    end

    def notify_scan_completed(scanner)
      unless active?
        application&.send_notification(SCAN_COMPLETED_NOTIFICATION, scan_notification(scanner))
      end
    end

    def scan_notification(scanner)
      Gio::Notification.new(Translations.gettext('Scan completed')).tap do |notification|
        notification.body = format(
          Translations.gettext('Completed scan of “%s”'),
          scanner.directory.parse_name,
        )
      end
    end

    # Upstream's reroot_treeview.
    def reroot_treeview(path, select_first: false)
      unless path.nil? || path.empty?
        folder_display.path = path
        charts.each_value { |chart| chart.tree_root = path }
        pathbar.path = path
        selection.model = folder_display.tree_sorter.tree_model_for(path)

        if select_first
          selection.selected = 0
        end
      end
    end

    # Upstream's go_up_treeview.
    def go_up_treeview
      folder_display.path.then do |path|
        unless path.nil? || path.depth <= 1
          reroot_treeview(path.parent)
        end
      end
    end

    def activate_row(position)
      selection.model.then do |model|
        row = model.get_item(position)
        if row.is_a?(Gtk::TreeListRow)
          reroot_treeview(row.item, select_first: true)
        end
      end
    end

    # Upstream's set_busy.
    def set_busy(busy)
      @is_busy = busy
      chart_stack_switcher.sensitive = !busy
      pathbar.sensitive = !busy
      if busy
        spinner_stack.visible_child_name = 'spinner'
      else
        spinner_stack.visible_child_name = 'charts'
      end
      if busy
        self.cursor = busy_cursor
      else
        self.cursor = nil
      end

      ACTIONS_WHILE_SCANNING.each do |name, enable|
        actions.fetch(name).enabled = busy == enable
      end
    end

    def busy_cursor = @busy_cursor ||= Gdk::Cursor.new('wait')

    # Upstream's set_ui_state.
    def set_ui_state(child, busy)
      set_busy(busy)

      case child
      when home_page then show_home_page
      else show_result_page
      end
    end

    def show_home_page
      actions.fetch('reload').enabled = false
      self.title = Translations.gettext('Devices & Locations')
      nav_view.pop
    end

    def show_result_page
      actions.fetch('reload').enabled = true
      self.title = @active_location&.name.to_s

      unless nav_view.visible_page == result_page
        nav_view.push_by_tag('results')
      end
    end

    def directory?(file)
      file.query_info('standard::type', :none).file_type == Gio::FileType::DIRECTORY
    rescue StandardError, GLib::Error
      false
    end

    def file_for(results) = @active_location.scanner.get_file(results)
    def clipboard = Gdk::Display.default.clipboard

    def trash(file)
      file.trash
      true
    rescue StandardError, GLib::Error => e
      report_trash_failure(file, e)
    end

    # Upstream lets an IOError.NOT_FOUND through, treating a file that is
    # already gone as trashed; the Ruby bindings do not expose the error code,
    # so the file itself is asked whether it is still there.
    def report_trash_failure(file, error)
      case
      when !exists?(file) then true
      else
        warn "Failed to move to file to the trash: #{error.message}"
        toast(Translations.gettext('Failed to trash file'))
        false
      end
    end

    def exists?(file)
      !file.query_info('standard::type', :none).nil?
    rescue StandardError, GLib::Error
      false
    end

    def drop_from_model(results)
      results.parent.then do |parent|
        unless parent.nil?
          parent.children_list_store.find(results).then do |found, position|
            if found
              parent.children_list_store.remove(position)
            end
          end
        end
      end
    end

    # Upstream's get_selected_item: the item the context menu was opened on,
    # or the selected row's item.
    def selected_item
      case
      when !@clicked_item.nil? then @clicked_item
      when selection.selected_item.is_a?(Gtk::TreeListRow) then selection.selected_item.item
      end
    end

    def with_selected_item
      selected_item.then do |item|
        unless item.nil?
          yield(item)
        end
      end
    end

    def selected_row
      selection.selected_item.then do |item|
        item.is_a?(Gtk::TreeListRow) ? item : nil
      end
    end

    def expand_selected_row
      selected_row&.expanded = true
    end

    # Upstream collapses an expanded row, and otherwise moves the selection to
    # the parent row.
    def collapse_selected_row
      selected_row.then do |row|
        case
        when row.nil? then nil
        when row.expanded? then row.expanded = false
        when row.depth.positive? then scroll_to_row(row.parent)
        end
      end
    end

    def scroll_to_row(row)
      position_of(row).then do |position|
        unless position.nil?
          column_view.scroll_to(
            position,
            nil,
            scroll_flags,
            nil,
          )
        end
      end
    end

    def scroll_flags
      Gtk::ListScrollFlags::FOCUS | Gtk::ListScrollFlags::SELECT
    end

    # Upstream's columnview_selection_find: a naive search for a row's position
    # in the sorted model, because a column view can only be scrolled to a
    # position. Upstream notes the same.
    def position_of(wanted)
      case wanted
      when nil then nil
      else selection.n_items.times.find { |index| selection.get_item(index) == wanted }
      end
    end

    def position_of_item(wanted)
      case wanted
      when nil then nil
      else selection.n_items.times.find { |index| row_holds?(selection.get_item(index), wanted) }
      end
    end

    def row_holds?(row, item)
      row.is_a?(Gtk::TreeListRow) && row.item == item
    end

    def show_treeview_popover_centred
      show_treeview_popover(column_view.width / 2, column_view.height / 2)
    end

    def show_treeview_popover(x, y)
      treeview_popover_menu.pointing_to = Gdk::Rectangle.new(
        x.to_i,
        y.to_i,
        0,
        0,
      )
      treeview_popover_menu.popup
      true
    end

    # Upstream's treeview_right_click_gesture_pressed: select the row under the
    # pointer, remember its item, and open the menu there.
    def right_clicked(x, y)
      @clicked_item = nil

      row_item_at(x, y).then do |item|
        unless item.nil?
          @clicked_item = item
          select_item(item)
        end
      end

      show_treeview_popover(x, y)
    end

    def row_item_at(x, y)
      column_view.pick(x, y, Gtk::PickFlags::INSENSITIVE | Gtk::PickFlags::NON_TARGETABLE)
                 .then { |picked| picked.nil? ? nil : file_cell_item(picked) }
    end

    # The cell the pointer is over is found by walking up from the picked
    # widget to the FileCell that holds the row's item.
    def file_cell_item(picked)
      Enumerator
        .produce(picked) { |widget| widget.nil? ? raise(StopIteration) : widget.parent }
        .take_while { |widget| !widget.nil? }
        .find { |widget| widget.is_a?(FileCell) }
        &.item
    end

    def select_item(item)
      position_of_item(item).then do |position|
        unless position.nil?
          column_view.scroll_to(
            position,
            nil,
            scroll_flags,
            nil,
          )
        end
      end
    end

    # Upstream puts these on a GtkShortcutController in the .ui file; the Ruby
    # bindings expose no trigger parser, so the same four keys are handled from
    # a key controller on the column view.
    def key_pressed(keyval, state)
      case [keyval, alt?(state)]
      when [Gdk::Keyval::KEY_Menu, false] then show_treeview_popover_centred
      when [Gdk::Keyval::KEY_Right, false] then handled { expand_selected_row }
      when [Gdk::Keyval::KEY_Left, false] then handled { collapse_selected_row }
      when [Gdk::Keyval::KEY_Up, true] then handled { go_up_treeview }
      else false
      end
    end

    def alt?(state) = state.to_i.anybits?(Gdk::ModifierType::ALT_MASK.to_i)

    def handled
      yield
      true
    end

    # Upstream's hide_columnview_header, which pokes into Gtk.ColumnView's
    # internals to find the header row and hide it, because the folder display
    # above the tree is the header. Nothing guarantees that structure, which is
    # why upstream says so too.
    def hide_column_view_header
      Enumerator
        .produce(column_view.first_child) { |widget| widget.nil? ? raise(StopIteration) : widget.next_sibling }
        .take_while { |widget| !widget.nil? }
        .select { |widget| widget.gtype.name == 'GtkColumnViewRowWidget' }
        .each { |widget| widget.visible = false }
    end
end
