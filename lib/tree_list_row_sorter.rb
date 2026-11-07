# frozen_string_literal: true

require 'adwaita'

require_relative 'scanner'

# TreeListRowSorter keeps a tree model's rows sorted without ever letting a
# child drift away from its parent.
#
# Ported from upstream's src/baobab-tree-list-row-sorter.vala. Upstream's file
# is a reimplementation of Gtk.TreeListRowSorter that adds a sort-order
# property, because sorting the flattened tree descending also reverses the
# parent/child relationship — https://gitlab.gnome.org/GNOME/gtk/-/issues/6695.
#
# That whole class is a workaround for sorting a flattened tree, and it cannot
# be ported literally: it overrides Gtk.Sorter's compare vfunc, and the Ruby
# bindings neither dispatch a GTK sort into a Ruby subclass's compare nor hand
# a Gtk::CustomSorter's block the real items — the block is called with raw
# pointers.
#
# So the port sorts the levels instead of the flattened tree: every parent's
# children list gets its own Gtk::SortListModel over the shared sorter, and the
# Gtk::TreeListModel flattens the already-sorted levels. A child cannot
# outrank its parent, because the two are never compared — which is the bug
# upstream's sort-order property exists to work around, structurally absent.
# Both sort directions then come straight from the column view's own sorter.
#
class TreeListRowSorter
  def initialize(sorter)
    @sorter = sorter
  end

  attr_reader :sorter

  # The tree model the column view shows, with every level sorted.
  def tree_model_for(results) = results.create_tree_model(sorter)

  # The column sorters upstream writes into data/ui/baobab-folder-display.ui,
  # one per column, each over the matching property of Scanner::Results.
  def self.column_sorters
    {
      folder:        string_sorter('display-name'),
      size:          numeric_sorter('size'),
      contents:      numeric_sorter('elements'),
      time_modified: numeric_sorter('time-modified'),
    }
  end

  # Built with no-arg constructors and the expression assigned after,
  # rather than passed as a constructor argument: the Ruby bindings marshal a
  # nil `expression` argument by ref-ing it as though it were already a live
  # GObject, which raises a GLib-GObject-CRITICAL (g_object_ref: assertion
  # 'G_IS_OBJECT (object)' failed) even though the call itself succeeds.
  # Setting the property after construction never marshals that nil.
  def self.string_sorter(property)
    Gtk::StringSorter.new.tap { |sorter| sorter.expression = expression(property) }
  end

  def self.numeric_sorter(property)
    Gtk::NumericSorter.new.tap { |sorter| sorter.expression = expression(property) }
  end

  # Built from a GLib::Param::Spec rather than the (type, nil, name) overload:
  # that overload has the same nil-expression marshalling problem this whole
  # method exists to avoid.
  def self.expression(property)
    Gtk::PropertyExpression.new(nil, Scanner::Results.property(property))
  end
end
