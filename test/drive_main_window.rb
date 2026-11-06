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
      # loop the driver's own timer runs on, until the results page shows or
      # ten seconds pass, rather than gambling on how many 500ms driver ticks
      # a drain happens to need.
      deadline = Time.now + 10
      context = GLib::MainContext.default

      until app.window.nav_view.visible_page.tag == 'results' || Time.now > deadline
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

      deadline = Time.now + 10
      context = GLib::MainContext.default

      until app.window.nav_view.visible_page.tag == 'results' || Time.now > deadline
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
