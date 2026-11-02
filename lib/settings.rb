# frozen_string_literal: true

require 'json'
require 'fileutils'

# Settings holds the keys of upstream's three GSettings schemas.
#
# Ported from upstream's data/org.gnome.baobab.gschema.xml: the
# org.gnome.baobab.preferences schema (excluded-uris) and the
# org.gnome.baobab.ui schema (active-chart, window-size, is-maximized).
#
# Upstream uses GSettings, which needs a compiled schema installed into the
# system's glib-2.0/schemas directory. Requiring an install step to run the app
# from a checkout is worse than the alternative, so the same keys, defaults and
# semantics are backed by a small JSON file under XDG_CONFIG_HOME instead.
#
class Settings
  # The window size default is upstream's (960, 600), split into the two keys
  # a JSON file can carry without a tuple type.
  DEFAULTS = {
    'excluded-uris' => [],
    'active-chart'  => 'rings',
    'window-width'  => 960,
    'window-height' => 600,
    'is-maximized'  => false,
  }.freeze

  # Upstream's <choices> for active-chart.
  CHARTS = %w[rings treemap].freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
  end

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = value
    write
    value
  end

  def location = @path

  DEFAULTS.each_key do |key|
    method_name = key.tr('-', '_')
    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }
  end

  def is_maximized? = self['is-maximized'] == true

  # active-chart is constrained to the schema's choices, so a hand-edited file
  # cannot leave the chart stack pointing at a page that does not exist.
  def active_chart
    CHARTS.include?(self['active-chart']) ? self['active-chart'] : DEFAULTS['active-chart']
  end

  def excluded_uris = Array(self['excluded-uris']).map(&:to_s)

  def add_excluded_uri(uri)
    excluded_uris.then do |uris|
      unless uris.include?(uri)
        self['excluded-uris'] = uris + [uri]
      end
    end
  end

  def remove_excluded_uri(uri)
    self['excluded-uris'] = excluded_uris.reject { |candidate| candidate == uri }
  end

  # Restores the geometry recorded by the previous run, the way upstream's
  # Window constructor does from the ui schema.
  def apply_to(window)
    window.set_default_size(self['window-width'], self['window-height'])

    if is_maximized?
      window.maximize
    end
  end

  # Records the geometry, skipping the size while maximized so the restored
  # size is the one the user actually chose — upstream's close_request does the
  # same check.
  def remember(window)
    @values['is-maximized'] = window.maximized?

    unless window.maximized?
      @values['window-width'] = window.default_size[0]
      @values['window-height'] = window.default_size[1]
    end

    write
  end

  private

    def default_path
      File.join(
        ENV.fetch('XDG_CONFIG_HOME', File.expand_path('~/.config')),
        'ruby-baobab',
        'settings.json',
      )
    end

    def read
      File.exist?(@path) ? JSON.parse(File.read(@path)) : {}
    rescue JSON::ParserError => e
      warn "Error parsing #{@path}: #{e.message}"
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, JSON.pretty_generate(@values))
    end
end
