# frozen_string_literal: true

require 'adwaita'

require_relative 'path_button'

# Pathbar is the row of buttons in the results header bar, one per folder from
# the scanned root down to the folder the tree is rooted at.
#
# Ported from upstream's Pathbar in src/baobab-pathbar.vala and
# data/ui/baobab-pathbar.ui: a horizontally scrolling box of PathButtons
# separated by path separators, which animates itself to the right-hand end
# whenever it grows so the current folder stays in view.
#
class Pathbar < Gtk::Box
  SEPARATOR = File::SEPARATOR

  # Upstream's DURATION for the scroll-to-end animation, in milliseconds.
  DURATION = 800

  def initialize
    super(:horizontal, 0)
    @location = nil
    @path = nil
    @item_activated_callbacks = []
    build
  end

  def build
    tap do |pathbar|
      pathbar.hexpand_set = true
      pathbar.overflow = :hidden
      pathbar.append(scrolled_window)

      scrolled_window.tap do |sw|
        sw.child = button_box
      end

      adjustment.tap do |adj|
        adj.signal_connect('changed') { animate_to_end }
        adj.signal_connect('notify::page-size') { adj.value = adj.upper }
      end
    end
  end

  attr_reader :location, :path

  # Upstream's item_activated signal.
  def on_item_activated(&block)
    @item_activated_callbacks << block
    block
  end

  # Upstream's location setter, which also resets the path to the location's
  # scanned root.
  def location=(value)
    @location = value
    self.path = value.scanner&.root
    value
  end

  # Upstream's path setter. The path is nil while a location is being scanned,
  # and a single button for the location's root is still wanted then.
  def path=(value)
    unless location.nil? || location.scanner.nil?
      @path = value
      clear
      fill(buttons_for(value))
    end

    value
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |sw|
      sw.hexpand = true
      sw.hscrollbar_policy = :external
      sw.vscrollbar_policy = :never
      sw.hadjustment = adjustment
    end
  end

  def adjustment = @adjustment ||= Gtk::Adjustment.new(
    0,
    0,
    0,
    0,
    0,
    0,
  )
  def button_box = @button_box ||= Gtk::Box.new(:horizontal, 0)

  private

    def item_activated(results)
      @item_activated_callbacks.dup.each { |callback| callback.call(results) }
    end

    # Upstream walks from the current directory up to the root, prepending as
    # it goes, so the buttons come out root first.
    def buttons_for(value)
      ancestry(value).map.with_index do |node, index|
        make_button(node, index.zero?)
      end.reverse
    end

    def ancestry(value)
      Enumerator
        .produce(value) { |node| node.nil? ? raise(StopIteration) : node.parent }
        .take_while { |node| !node.nil? }
        .then { |nodes| nodes.empty? ? [nil] : nodes }
    end

    def fill(buttons)
      buttons.each_with_index do |button, index|
        button_box.append(segment(button, index.zero?))
      end
    end

    # Each button past the first is preceded by a dimmed path separator.
    def segment(button, first)
      Gtk::Box.new(:horizontal, 0).tap do |box|
        unless first
          box.append(separator_label)
        end

        box.append(button)
      end
    end

    def separator_label
      Gtk::Label.new(SEPARATOR).tap { |label| label.add_css_class('dim-label') }
    end

    def clear
      while button_box.first_child
        button_box.remove(button_box.first_child)
      end
    end

    # Upstream's make_button: the root's button carries the location's name and
    # icon, every other button the node's display name.
    def make_button(node, current_dir)
      label_for(node).then do |label, gicon|
        PathButton.new(label, gicon, current_dir).tap do |button|
          unless node.nil? || current_dir
            button.signal_connect('clicked') { item_activated(node) }
          end
        end
      end
    end

    def label_for(node)
      case
      when node.nil? || node.depth == 1 then [location.name.to_s, location.symbolic_icon]
      else [node.display_name.to_s, nil]
      end
    end

    # Upstream animates the adjustment to its upper bound whenever the content
    # grows, so a newly appended button scrolls into view.
    def animate_to_end
      Adwaita::TimedAnimation.new(
        self,
        adjustment.value,
        adjustment.upper,
        DURATION,
        Adwaita::PropertyAnimationTarget.new(adjustment, 'value'),
      ).tap do |animation|
        animation.easing = :ease_out_cubic
        animation.play
      end
    end
end
