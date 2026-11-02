# frozen_string_literal: true

require 'adwaita'

require_relative 'chart_menu'
require_relative 'formatters'
require_relative 'scanner'

# ChartItem is one slice or rectangle of a chart.
#
# Ported from upstream's ChartItem in src/baobab-chart.vala.
class ChartItem
  attr_accessor :depth,
    :rel_start,
    :rel_size,
    :results,
    :visible,
    :has_visible_children,
    :rect,
    :parent

  def initialize
    @depth = 0
    @rel_start = 0.0
    @rel_size = 0.0
    @results = nil
    @visible = false
    @has_visible_children = false
    @rect = Gdk::Rectangle.new(
      0,
      0,
      0,
      0,
    )
    @parent = nil
  end

  def visible? = @visible
  def has_visible_children? = @has_visible_children
end

# Chart is what the rings chart and the treemap have in common: the item tree
# built from a scan, the colours, the pointer handling, the context menu, the
# zoom actions and the tooltip.
#
# Ported from upstream's src/baobab-chart.vala, an abstract Gtk.DrawingArea
# subclass. The subclass hooks upstream declares abstract — draw_item,
# calculate_item_geometry, point_over_item?, get_item_rectangle, can_zoom_in,
# can_zoom_out and create_new_chartitem — are the methods a subclass overrides
# here too.
#
# Upstream overrides size_allocate to recalculate every item's geometry; the
# Ruby bindings cannot override a vfunc, so the drawing area's own resize
# signal does it.
#
class Chart < Gtk::DrawingArea
  MAX_DEPTH = 5
  MIN_DEPTH = 1

  # Keep in sync with the colours upstream defines in baobab-chart.vala.
  CHART_COLORS = %w[#e01b24 #ff7800 #f6d32d #33d17a #3584e4 #9141ac].freeze
  NUM_COLORS = 6

  ROOT_COLOR = '#d3d6d1'
  ROOT_HIGHLIGHT_COLOR = '#e0e2dd'

  ACTIONS = %w[open-file copy-path trash-file move-up zoom-in zoom-out].freeze

  def initialize
    super
    @items = []
    @max_depth = MAX_DEPTH
    @model = nil
    @tree_root = nil
    @location = nil
    @highlighted_item = nil
    @popover_item = nil
    @model_changed = false
    @item_activated_callbacks = []
    @file_action_callbacks = {}
    build
  end

  attr_reader :items, :max_depth, :highlighted_item, :location

  def build
    tap do |chart|
      chart.set_draw_func { |_, context, width, height| draw_func(context, width, height) }
      chart.signal_connect('resize') { recalculate_geometry }
      chart.signal_connect('query-tooltip') { |_, x, y, _keyboard, tooltip| query_tooltip(x, y, tooltip) }

      add_controllers
      insert_action_group('chart', action_group)
      context_menu.set_parent(chart)
    end
  end

  # Upstream's item_activated signal.
  def on_item_activated(&block)
    @item_activated_callbacks << block
    block
  end

  # Upstream's chart actions reach the window through get_root; the window
  # registers what each one does instead.
  def on_file_action(name, &block)
    @file_action_callbacks[name] = block
    block
  end

  # Upstream's location setter, which also follows the scanner's max depth.
  def location=(value)
    @location = value
    self.model = value.scanner.root.create_tree_model
    max_depth_from_scanner(value.scanner)
    value
  end

  # Upstream's tree_root setter.
  def tree_root=(value)
    unless @model.nil? || @tree_root == value
      @tree_root = value
      self.highlighted_item = nil
      queue_draw
    end

    value
  end

  # Upstream falls back to the scanner's root when no subtree has been chosen.
  def tree_root
    case
    when !@tree_root.nil? then @tree_root
    when !location.nil? && !location.scanner.nil? then location.scanner.root
    end
  end

  def max_depth=(value)
    value.clamp(MIN_DEPTH, MAX_DEPTH).then do |clamped|
      unless @max_depth == clamped
        @max_depth = clamped
        @model_changed = true
        max_depth_changed
        queue_draw
      end
    end

    value
  end

  def highlighted_item=(value)
    unless @highlighted_item == value
      @highlighted_item = value
      highlighted_item_changed
      queue_draw
    end

    value
  end

  # Upstream's move_up_root, also on the chart.move-up action.
  def move_up_root
    tree_root.then do |root|
      unless root.nil? || root.parent.nil?
        self.tree_root = root.parent
        item_activated(root.parent)
      end
    end
  end

  def zoom_in
    if can_zoom_in?
      self.max_depth = max_depth - 1
    end
  end

  def zoom_out
    if can_zoom_out?
      self.max_depth = max_depth + 1
    end
  end

  # Upstream's can_move_up_root.
  def can_move_up_root? = !tree_root.nil? && !tree_root.parent.nil?

  # The hooks a subclass fills in. Upstream declares them abstract.
  def draw_item(_context, _item, _highlighted) = nil
  def calculate_item_geometry(_item) = nil
  def point_over_item?(_item, _x, _y) = false
  def get_item_rectangle(_item) = nil
  def can_zoom_in? = false
  def can_zoom_out? = false
  def create_chart_item = ChartItem.new
  def post_draw(_context) = nil

  # Hooks the rings chart uses to drop its sub-tooltips.
  def max_depth_changed = nil
  def highlighted_item_changed = nil

  def action_group
    @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
      actions.each_value { |action| group.add_action(action) }
    end
  end

  def actions
    @actions ||= ACTIONS.to_h { |name| [name, build_action(name)] }
  end

  def context_menu
    @context_menu ||= Gtk::PopoverMenu.new(ChartMenu.new.build).tap do |menu|
      menu.position = :bottom
    end
  end

  protected

    def model=(value)
      unless @model == value
        disconnect_model
        @model = value
        @model_changed = true
        @tree_root = nil
        connect_model
        queue_draw
      end

      value
    end

    # Upstream's get_item_color: a colour interpolated between two of the six
    # chart colours, dimmed by depth and brightened when highlighted.
    def item_color(rel_position, depth, highlighted)
      case depth
      when 0 then root_color(highlighted)
      else highlight(depth_color(rel_position, depth), depth, highlighted)
      end
    end

  private

    def item_activated(results)
      @item_activated_callbacks.dup.each { |callback| callback.call(results) }
    end

    def build_action(name)
      Gio::SimpleAction.new(name).tap do |action|
        action.signal_connect('activate') { activate_action_named(name) }
      end
    end

    def activate_action_named(name)
      case name
      when 'move-up' then move_up_root
      when 'zoom-in' then zoom_in
      when 'zoom-out' then zoom_out
      else run_file_action(name)
      end
    end

    def run_file_action(name)
      unless @popover_item.nil?
        @file_action_callbacks[name]&.call(@popover_item.results)
      end
    end

    def add_controllers
      add_controller(scroll_controller)
      add_controller(motion_controller)
      add_controller(primary_click_gesture)
      add_controller(secondary_click_gesture)
      add_controller(middle_click_gesture)
    end

    def scroll_controller
      @scroll_controller ||= Gtk::EventControllerScroll.new(Gtk::EventControllerScrollFlags::BOTH_AXES).tap do |controller|
        controller.signal_connect('scroll') { |_, dx, dy| scrolled(dx, dy) }
      end
    end

    def motion_controller
      @motion_controller ||= Gtk::EventControllerMotion.new.tap do |controller|
        controller.signal_connect('motion') { |_, x, y| self.has_tooltip = highlight_item_at_point(x, y) }
        controller.signal_connect('enter') { |_, x, y| entered(x, y) }
      end
    end

    def primary_click_gesture
      @primary_click_gesture ||= click_gesture(Gdk::BUTTON_PRIMARY) { |x, y| primary_pressed(x, y) }
    end

    def secondary_click_gesture
      @secondary_click_gesture ||= click_gesture(Gdk::BUTTON_SECONDARY) { |x, y| show_popover_at(x.to_i, y.to_i) }
    end

    def middle_click_gesture
      @middle_click_gesture ||= click_gesture(Gdk::BUTTON_MIDDLE) { |_x, _y| move_up_root }
    end

    def click_gesture(button, &pressed)
      Gtk::GestureClick.new.tap do |gesture|
        gesture.button = button
        gesture.signal_connect('pressed') { |_, _n_press, x, y| pressed.call(x, y) }
      end
    end

    def primary_pressed(x, y)
      if highlight_item_at_point(x, y)
        activate_or_move_up
      end
    end

    def activate_or_move_up
      if tree_root == highlighted_item.results
        move_up_root
      else
        item_activated(highlighted_item.results)
      end
    end

    def entered(x, y)
      unless context_menu.visible?
        self.has_tooltip = highlight_item_at_point(x, y)
      end
    end

    # Upstream scrolls up or left to zoom out, down or right to zoom in.
    def scrolled(delta_x, delta_y)
      case
      when delta_x.positive? || delta_y.negative? then zoom_out_and_stop
      when delta_x.negative? || delta_y.positive? then zoom_in_and_stop
      else false
      end
    end

    def zoom_out_and_stop
      zoom_out
      true
    end

    def zoom_in_and_stop
      zoom_in
      true
    end

    def highlight_item_at_point(x, y)
      items.reverse.find { |item| item.visible? && point_over_item?(item, x, y) }
           .then do |found|
             self.highlighted_item = found
             !found.nil?
           end
    end

    def draw_func(context, _width, _height)
      unless @model.nil?
        rebuild_items_if_needed
        draw_chart(context)
      end
    end

    def rebuild_items_if_needed
      if @model_changed || items.empty? || items.first.results != tree_root
        collect_items(tree_root)
      end
    end

    def draw_chart(context)
      context.save
      items.each { |item| draw_visible_item(context, item) }
      context.restore
      post_draw(context)
    end

    def draw_visible_item(context, item)
      if item.visible? && item.depth <= max_depth
        draw_item(context, item, item == highlighted_item)
      end
    end

    # Upstream's get_items: breadth-first from the chart's root, calculating
    # each item's geometry before its children are added, and stopping a branch
    # as soon as an item turns out to be invisible.
    def collect_items(root_path)
      @items = []
      @model_changed = false

      unless root_path.nil?
        expand_from(
          add_item(
            0,
            0,
            100,
            root_path,
            nil,
          ),
        )
      end
    end

    def expand_from(first)
      [first].tap do |pending|
        until pending.empty?
          expand_item(pending.shift, pending)
        end
      end
    end

    def expand_item(item, pending)
      calculate_item_geometry(item)

      if item.visible? && !item.results.empty? && item.depth < max_depth + 1
        pending.concat(add_children(item))
      end
    end

    def add_children(item)
      children_by_size(item.results).inject([0.0, []]) do |(rel_start, added), child|
        [rel_start + child.percent, added + [add_item(
          item.depth + 1,
          rel_start,
          child.percent,
          child,
          item,
        )
]
]
      end.last
    end

    # Upstream sorts each level by size, largest first.
    def children_by_size(results)
      results.children_list_store.n_items.times
             .map { |index| results.children_list_store.get_item(index) }
             .sort_by { |child| -child.size }
    end

    def add_item(depth, rel_start, rel_size, results, parent)
      create_chart_item.tap do |item|
        item.depth = depth
        item.rel_start = rel_start
        item.rel_size = rel_size
        item.results = results
        item.parent = parent
        @items << item
      end
    end

    def recalculate_geometry
      items.each do |item|
        item.has_visible_children = false
        item.visible = false
        calculate_item_geometry(item)
      end
    end

    def connect_model
      unless @model.nil?
        @items_changed_handler = @model.signal_connect('items-changed') { items_changed }
      end
    end

    def disconnect_model
      unless @model.nil? || @items_changed_handler.nil?
        @model.signal_handler_disconnect(@items_changed_handler)
        @items_changed_handler = nil
      end
    end

    def items_changed
      @model_changed = true

      if realized?
        queue_draw
      end
    end

    def max_depth_from_scanner(scanner)
      self.max_depth = scanner.max_depth
      scanner.on_max_depth_changed { |depth| self.max_depth = depth }
    end

    def query_tooltip(_x, _y, tooltip)
      highlighted_item.then do |item|
        case item
        when nil then false
        else fill_tooltip(tooltip, item)
        end
      end
    end

    def fill_tooltip(tooltip, item)
      tooltip.set_tip_area(item.rect)
      tooltip.set_markup(
        Formatters.escape_markup("#{item.results.display_name}\n#{Formatters.format_size(item.results.size)}"),
      )
      true
    end

    def show_popover_at(x, y)
      @popover_item = highlighted_item
      update_action_sensitivity
      context_menu.pointing_to = Gdk::Rectangle.new(
        x,
        y,
        0,
        0,
      )
      context_menu.popup
    end

    def update_action_sensitivity
      %w[open-file copy-path trash-file].each do |name|
        actions.fetch(name).enabled = !highlighted_item.nil?
      end

      actions.fetch('move-up').enabled = can_move_up_root?
      actions.fetch('zoom-in').enabled = can_zoom_in?
      actions.fetch('zoom-out').enabled = can_zoom_out?
    end

    def root_color(highlighted)
      Gdk::RGBA.parse(highlighted ? ROOT_HIGHLIGHT_COLOR : ROOT_COLOR)
    end

    # Upstream dims a colour by depth, so deeper rings are darker.
    def depth_color(rel_position, depth)
      intensity = 1 - (((depth - 1) * 0.3) / MAX_DEPTH)
      third = 100.0 / 3

      (rel_position / third).to_i.then do |index|
        interpolate(
          chart_color(index),
          chart_color((index + 1) % NUM_COLORS),
          (rel_position - index * third) / third,
        ).then { |color| scale(color, intensity) }
      end
    end

    def highlight(color, depth, highlighted)
      case
      when !highlighted then color
      when depth.zero? then root_color(true)
      else brighten(color)
      end
    end

    # Upstream divides the channels by the largest of them, which pushes the
    # colour to full saturation without changing its hue.
    def brighten(color)
      [color.red, color.green, color.blue].max.then do |maximum|
        case maximum
        when 0 then color
        else Gdk::RGBA.new(
          color.red / maximum,
          color.green / maximum,
          color.blue / maximum,
          1.0,
        )
        end
      end
    end

    def scale(color, factor)
      Gdk::RGBA.new(
        color.red * factor,
        color.green * factor,
        color.blue * factor,
        1.0,
      )
    end

    def interpolate(color_a, color_b, percentage)
      Gdk::RGBA.new(
        channel(color_a.red, color_b.red, percentage),
        channel(color_a.green, color_b.green, percentage),
        channel(color_a.blue, color_b.blue, percentage),
        1.0,
      )
    end

    def channel(from, to, percentage) = from - (from - to) * percentage

    def chart_color(index) = chart_colors.fetch(index % NUM_COLORS)

    def chart_colors
      @chart_colors ||= CHART_COLORS.map { |hex| Gdk::RGBA.parse(hex) }
    end
end
