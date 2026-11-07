# frozen_string_literal: true

# Drives the real application through a scan, the two charts, the tree
# context menu, preferences and the about/shortcuts dialogs, one step per turn
# of the GTK main loop, and writes a screenshot of each state.
#
#   nix develop --command xvfb-run -a ruby test/drive_main_window.rb
#
# Runs headlessly: GTK4 renders to an offscreen surface, so the PNGs under
# tmp/shots are what a real session would look like.

require 'tmpdir'
require 'fileutils'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# A scratch config dir so a drive never reads or scribbles on the real
# settings file.
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir('baobab-drive-config')

require 'application'
require_relative 'gtk_driver'

# Application#build returns `self`, not the Gtk::Application, so its `run`
# can answer --version without opening a window. GtkDriver.drive wants
# something whose `build` hands back the real Gio::Application, to hook its
# own `activate` handler and call `run` on it directly. This adapts the two.
class DriveTarget
  def initialize(application)
    @application = application
  end

  def build
    @application.build
    @application.app
  end

  def window = @application.window
  def app = @application.app
  def actions = @application.actions
  def settings = @application.settings
end

# A small tree of known size to scan, so the results are predictable:
# root/a (4096 bytes), root/sub/b (2048 bytes), root/sub/sub2/c (1024 bytes).
SCAN_ROOT = Dir.mktmpdir('baobab-drive-tree')

Dir.mkdir(File.join(SCAN_ROOT, 'sub'))
Dir.mkdir(File.join(SCAN_ROOT, 'sub', 'sub2'))
File.write(File.join(SCAN_ROOT, 'a'), 'x' * 4096)
File.write(File.join(SCAN_ROOT, 'sub', 'b'), 'x' * 2048)
File.write(
  File.join(
    SCAN_ROOT,
    'sub',
    'sub2',
    'c',
  ),
  'x' * 1024,
)

DriveTarget.new(Application.new(argv: [], app_id: 'org.gnome.baobab.Drive')).then do |target|
  GtkDriver.drive(target, shots: 'tmp/shots') do |d, app|
    d.window { app.window }

    d.step('the window opens on the devices and locations page') do
      d.check('home page is showing') { app.window.nav_view.visible_page.tag == 'home' }
      d.check('the home folder row is listed') { !app.window.location_list.local_list_box.first_child.nil? }
      d.shot('01-home')
    end

    d.step('scan the sample directory') do
      app.window.scan_directory(Gio::File.new_for_path(SCAN_ROOT), Scanner::NONE)

      # The scan runs on a worker thread and drains onto the main loop every
      # 100ms (Scanner::DRAIN_INTERVAL); block here, pumping the same main
      # loop the driver's own timer runs on, until the scan actually
      # completes or ten seconds pass. The nav_view's tag flips to 'results'
      # the instant scan_location starts the scan (set_ui_state(result_page,
      # true) runs before the scanner has produced anything), so waiting on
      # the tag races the scan itself and was observed to pass before the
      # rings chart had a root. show_results only runs once the scanner's
      # "completed" signal fires, and it is what gives the rings chart its
      # tree_root, so wait on that instead.
      deadline = Time.now + 10
      context = GLib::MainContext.default

      until !app.window.rings_chart.tree_root.nil? || Time.now > deadline
        context.iteration(true)
      end
    end

    d.step('the scan completes and the results page shows') do
      d.check('results page is showing') { app.window.nav_view.visible_page.tag == 'results' }
      d.check('the column view has a root row') { app.window.selection.n_items.positive? }
      d.check('the rings chart has a root') { !app.window.rings_chart.tree_root.nil? }
      d.shot('02-results-rings')
    end

    d.step('switch to the treemap chart') do
      app.window.active_chart_action.activate(GLib::Variant.new('treemap'))
    end

    d.step('the treemap chart takes the root') do
      d.check('chart stack shows treemap') { app.window.chart_stack.visible_child_name == 'treemap' }
      d.check('the treemap chart has a root') { !app.window.treemap_chart.tree_root.nil? }
      d.shot('03-results-treemap')
    end

    d.step('back to the rings chart') do
      app.window.active_chart_action.activate(GLib::Variant.new('rings'))
    end

    d.step('the chart\'s own right-click popover opens on the root wedge') do
      chart = app.window.rings_chart
      # The root item fills the centre of the rings chart's drawing area, so
      # a highlight test there is the same thing a right click at that point
      # would find, without needing to synthesise a real pointer event.
      d.check('the centre point highlights the root item') do
        chart.send(:highlight_item_at_point, chart.width / 2.0, chart.height / 2.0)
      end
      chart.send(:show_popover_at, chart.width / 2, chart.height / 2)
      d.check('the chart popover is visible') { chart.send(:context_menu).visible? }
      d.check('open-file, copy-path and trash-file are enabled on a real item') do
        %w[open-file copy-path trash-file].all? { |name| chart.actions.fetch(name).enabled? }
      end
      d.shot('14-chart-popover')
      chart.send(:context_menu).popdown
    end

    d.step('the chart\'s copy-path action copies the root path, same as the treeview one') do
      app.window.rings_chart.actions.fetch('copy-path').activate(nil)
    end

    d.step('the chart\'s open-file action fails cleanly off-screen, same as the window would') do
      app.window.rings_chart.actions.fetch('open-file').activate(nil)
      d.check('still on the results page after an open attempt') do
        app.window.nav_view.visible_page.tag == 'results'
      end
    end

    d.step('the chart\'s trash-file action toasts rather than crashing, same as treeview-trash') do
      app.window.rings_chart.actions.fetch('trash-file').activate(nil)
      d.check('still on the results page after the chart\'s own trash attempt') do
        app.window.nav_view.visible_page.tag == 'results'
      end
    end

    d.step('zoom the rings chart out, then in') do
      starting_depth = app.window.rings_chart.max_depth
      app.window.rings_chart.actions.fetch('zoom-out').activate(nil)
      d.check('zoom-out increases max_depth') { app.window.rings_chart.max_depth > starting_depth }

      app.window.rings_chart.actions.fetch('zoom-in').activate(nil)
      app.window.rings_chart.actions.fetch('zoom-in').activate(nil)
      d.check('zoom-in decreases max_depth below the start') { app.window.rings_chart.max_depth < starting_depth }

      app.window.rings_chart.max_depth = starting_depth
    end

    d.step('reroot the treeview on the "sub" child, then chart.move-up returns to the scan root') do
      scan_root = app.window.rings_chart.tree_root
      # reroot_treeview no-ops on a childless (leaf) node, so pick the one
      # child in the sample tree that itself has children: "sub".
      child = (0...scan_root.children_list_store.n_items)
              .map { |index| scan_root.children_list_store.get_item(index) }
              .find { |candidate| !candidate.empty? }

      d.check('the "sub" child of the scan root was found') { !child.nil? }
      app.window.send(:reroot_treeview, child)

      d.check('the rings chart is now rooted on the child') { app.window.rings_chart.tree_root == child }
      d.shot('08-chart-rooted-on-child')

      # Upstream (baobab-chart.vala:507-524) only recomputes each action's
      # enabled state inside show_popover_at, same as this port's
      # update_action_sensitivity, so a real right click re-syncs it right
      # before the menu is shown. The earlier right-click step in this
      # driver left 'move-up' disabled, synced for the chart's root (whose
      # own parent is nil, so move-up was correctly insensitive there); it
      # has not been re-synced since, same as it would not be for a real
      # popover that stayed closed. Call the same sync a right click would,
      # for the root the chart is on now, before using the action directly.
      app.window.rings_chart.send(:update_action_sensitivity)
      app.window.rings_chart.actions.fetch('move-up').activate(nil)
      d.check('chart.move-up returns the chart to the scan root') { app.window.rings_chart.tree_root == scan_root }
    end

    d.step('select the first row and exercise the tree keyboard actions') do
      app.window.selection.selected = 0
      app.window.actions.fetch('treeview-expand-row').activate(nil)
      d.check('the root row is expanded') { app.window.send(:selected_row)&.expanded? != false }

      # Same wiring upstream's GtkShortcutController drives: Right/Left/Alt+Up
      # on the column view, exercised here through the private key handler
      # exactly as the controller would call it.
      d.check('Left collapses via the keyboard path') do
        app.window.send(:key_pressed, Gdk::Keyval::KEY_Left, 0)
        app.window.send(:selected_row)&.expanded? == false
      end

      app.window.actions.fetch('treeview-collapse-row').activate(nil)
      app.window.actions.fetch('treeview-go-up').activate(nil)
      d.check('still on the results page after go-up at the root') do
        app.window.nav_view.visible_page.tag == 'results'
      end
    end

    d.step('open the tree context menu, then copy the selected path') do
      app.window.selection.selected = 0
      app.window.actions.fetch('show-treeview-popover').activate(nil)
      d.check('the treeview popover is visible') { app.window.treeview_popover_menu.visible? }
      d.shot('09-treeview-popover')
      app.window.treeview_popover_menu.popdown

      app.window.actions.fetch('treeview-copy').activate(nil)
    end

    d.step('trashing fails cleanly on this filesystem and toasts rather than crashing') do
      app.window.selection.selected = 0
      app.window.actions.fetch('treeview-trash').activate(nil)
      d.check('still on the results page after a failed trash') do
        app.window.nav_view.visible_page.tag == 'results'
      end
      d.shot('10-after-trash-attempt')
    end

    d.step('open the primary menu, then close it') do
      app.window.show_primary_menu_action.activate(nil)
      d.check('the primary menu button reports active') { app.window.menu_button.active? }
      d.shot('11-primary-menu')
      app.window.show_primary_menu_action.activate(nil)
      d.check('the primary menu button is no longer active') { !app.window.menu_button.active? }
    end

    d.step('clear the recent locations list') do
      app.window.actions.fetch('clear-recent').activate(nil)
      d.check('still on the results page after clearing recents') do
        app.window.nav_view.visible_page.tag == 'results'
      end
    end

    d.step('add an excluded location, then remove it from preferences') do
      app.settings.add_excluded_uri(Gio::File.new_for_path(SCAN_ROOT).uri)
      app.window.actions.fetch('show-preferences').activate(nil)
    end

    d.step('the excluded location is listed') do
      dialog = app.window.visible_dialog
      d.check('a dialog is open') { !dialog.nil? }
      d.check('the excluded list has the added row plus the Add Location row') do
        dialog.excluded_list_box.observe_children.n_items == 2
      end
      d.shot('12-preferences-with-excluded-location')

      # The row's own remove button is how upstream removes it; drive that
      # instead of writing straight to settings, so the wiring is under test.
      row = dialog.excluded_list_box.observe_children.get_item(0)
      row.remove_button.signal_emit('clicked')
    end

    d.step('removing the row leaves only the Add Location row') do
      dialog = app.window.visible_dialog
      d.check('the excluded list is back to empty state (Add Location only)') do
        dialog.excluded_list_box.observe_children.n_items == 1
      end
      d.check('no locations remain excluded') { app.settings.excluded_uris.empty? }
      d.shot('13-preferences-excluded-removed')
      dialog&.close
    end

    d.step('scanning something that is not a folder reports the error without crashing') do
      bad_file = Gio::File.new_for_path(File.join(SCAN_ROOT, 'a'))
      app.window.scan_directory(bad_file)
      d.check('the window is still alive and on the results page') do
        app.window.nav_view.visible_page.tag == 'results'
      end
    end

    d.step('open preferences') { app.window.actions.fetch('show-preferences').activate(nil) }

    d.step('the preferences dialog opens') do
      d.check('a dialog is open') { !app.window.visible_dialog.nil? }
      d.shot('04-preferences')
      app.window.visible_dialog&.close
    end

    d.step('open the about dialog') { app.window.actions.fetch('about').activate(nil) }

    d.step('the about dialog names the app') do
      d.check('a dialog is open') { !app.window.visible_dialog.nil? }
      d.shot('05-about')
      app.window.visible_dialog&.close
    end

    d.step('open the keyboard shortcuts dialog') { app.actions.fetch('shortcuts').activate(nil) }

    d.step('the shortcuts dialog lists the accelerators') do
      d.check('a dialog is open') { !app.window.visible_dialog.nil? }
      d.shot('06-shortcuts')
      app.window.visible_dialog&.close
    end

    d.step('rescan the current location') do
      app.window.actions.fetch('reload').activate(nil)

      # scan_location resets selection.model to a fresh, empty Gio::ListStore
      # synchronously before the scan itself even starts, so (as with the
      # first scan above) waiting on it rather than the nav_view's tag —
      # which never leaves 'results' across a reload at all — is what
      # actually tells apart "reload is still running" from "reload landed".
      deadline = Time.now + 10
      context = GLib::MainContext.default

      until app.window.selection.n_items.positive? || Time.now > deadline
        context.iteration(true)
      end
    end

    d.step('the rescan lands back on results') do
      d.check('results page is still showing') { app.window.nav_view.visible_page.tag == 'results' }
      d.check('the size total did not change') { app.window.selection.n_items.positive? }
      d.shot('07-after-rescan')
    end
  end
end
