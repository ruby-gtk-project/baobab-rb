# frozen_string_literal: true

require 'adwaita'

require_relative 'contents_cell'
require_relative 'folder_cell'
require_relative 'scanner'
require_relative 'size_cell'
require_relative 'time_modified_cell'
require_relative 'translations'
require_relative 'tree_list_row_sorter'

# FolderDisplay is the header above the results tree: one row showing the
# folder the tree is rooted at, with the column titles that sort the tree.
#
# Ported from upstream's src/baobab-folder-display.vala and
# data/ui/baobab-folder-display.ui: an Adw.Bin around a Gtk.ColumnView whose
# model holds exactly one Scanner.Results, with four columns — Folder, Size,
# Contents and Modified — and the size groups that keep the header's cells
# lined up with the cells of the window's own column view.
#
# The column view's sorter is what the window sorts the results tree with, and
# it is reached through TreeListRowSorter.
#
class FolderDisplay < Adwaita::Bin
  COLUMNS = %i[folder size contents time_modified].freeze

  def initialize
    super
    @location = nil
    @path = nil
    @activated_callbacks = []
    @progress_handler = nil
    build
  end

  def build
    tap do |display|
      display.child = column_view

      column_view.tap do |view|
        view.model = selection
        COLUMNS.each { |name| view.append_column(column(name)) }
        view.signal_connect('activate') { activated }
        view.sort_by_column(column(:size), :descending)
      end

      add_header_cells_to_size_groups
    end
  end

  # Upstream's activated signal, emitted when the header row is clicked.
  def on_activated(&block)
    @activated_callbacks << block
    block
  end

  def activated
    @activated_callbacks.dup.each(&:call)
  end

  attr_reader :location, :path

  # Upstream's location setter: show the location's name with the totals the
  # scanner reports as it goes, so the header counts up during a scan.
  def location=(value)
    disconnect_progress
    @location = value

    Scanner::Results.empty.then do |results|
      results.display_name = value.name.to_s
      show(results)
      @progress_handler = value.on_progress { update_totals(results) }
    end

    value
  end

  # Upstream's path setter: once a scan is done the header shows the node the
  # tree is rooted at.
  def path=(value)
    @path = value
    show(value)
    value
  end

  # The sorter the window's results tree is sorted by.
  def sorter = column_view.sorter

  def tree_sorter = @tree_sorter ||= TreeListRowSorter.new(sorter)

  # Upstream exposes one horizontal size group per column so the window's
  # cells line up under the header's.
  def size_groups
    @size_groups ||= COLUMNS.to_h { |name| [name, Gtk::SizeGroup.new(:horizontal)] }
  end

  def size_group(name) = size_groups.fetch(name)

  def column_view
    @column_view ||= Gtk::ColumnView.new.tap do |view|
      view.hexpand = true
      view.reorderable = false
      view.single_click_activate = true
    end
  end

  def selection = @selection ||= Gtk::NoSelection.new(store)
  def store = @store ||= Gio::ListStore.new(Scanner::Results)

  def column(name) = columns.fetch(name)

  def columns
    @columns ||= COLUMNS.to_h { |name| [name, build_column(name)] }
  end

  TITLES = {
    folder:        'Folder',
    size:          'Size',
    contents:      'Contents',
    time_modified: 'Modified',
  }.freeze

  CELL_CLASSES = {
    folder:        FolderCell,
    size:          SizeCell,
    contents:      ContentsCell,
    time_modified: TimeModifiedCell,
  }.freeze

  private

    def build_column(name)
      Gtk::ColumnViewColumn.new(Translations.gettext(TITLES.fetch(name)), factory(name)).tap do |col|
        col.expand = name == :folder
        col.sorter = column_sorters.fetch(name)
      end
    end

    def column_sorters
      @column_sorters ||= TreeListRowSorter.column_sorters
    end

    # Upstream's per-column setup/bind/unbind/teardown callbacks, which also
    # move each cell in and out of the column's size group.
    def factory(name)
      Gtk::SignalListItemFactory.new.tap do |f|
        f.signal_connect('setup') { |_, cell| setup_cell(name, cell) }
        f.signal_connect('bind') { |_, cell| cell.child.item = cell.item }
        f.signal_connect('unbind') { |_, cell| cell.child.item = nil }
        f.signal_connect('teardown') { |_, cell| size_group(name).remove_widget(cell.child) }
      end
    end

    def setup_cell(name, cell)
      CELL_CLASSES.fetch(name).new.then do |child|
        cell.child = child
        size_group(name).add_widget(child)
      end
    end

    def show(results)
      store.remove_all
      unless results.nil?
        store.append(results)
      end
    end

    def update_totals(results)
      location&.scanner.then do |scanner|
        unless scanner.nil?
          results.size = scanner.total_size
          results.elements = scanner.total_elements
          refresh_header
        end
      end
    end

    # The header's one row is rebuilt rather than notified, because the cells
    # read their item once on bind.
    def refresh_header
      store.n_items.positive?.then do |has_row|
        if has_row
          store.get_item(0).then { |results| show(results) }
        end
      end
    end

    def disconnect_progress
      unless @progress_handler.nil? || @location.nil?
        @location.disconnect_progress(@progress_handler)
        @progress_handler = nil
      end
    end

    # Upstream's add_header_cells_to_size_groups, which pokes into
    # Gtk.ColumnView's internal structure to find the header row's title cells.
    # Nothing guarantees that structure, which is why upstream says so too; the
    # type names are checked before anything is touched.
    def add_header_cells_to_size_groups
      header_row.then do |row|
        unless row.nil?
          title_cells(row).each_with_index do |cell, index|
            size_group(COLUMNS[index]).add_widget(cell.first_child)
          end
        end
      end
    end

    def header_row
      siblings(column_view.first_child).find { |child| type_name(child) == 'GtkColumnViewRowWidget' }
    end

    def title_cells(row)
      siblings(row.first_child)
        .take_while { |cell| type_name(cell) == 'GtkColumnViewTitle' }
        .first(COLUMNS.length)
        .then { |cells| cells.length == COLUMNS.length ? cells : [] }
    end

    def siblings(first)
      Enumerator
        .produce(first) { |widget| widget.nil? ? raise(StopIteration) : widget.next_sibling }
        .take_while { |widget| !widget.nil? }
    end

    def type_name(widget) = widget.gtype.name
end
