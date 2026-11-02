# frozen_string_literal: true

# Translations resolves the user-visible strings against upstream's message
# catalogues.
#
# Ported from upstream's po/ directory (116 locales, listed in po/LINGUAS and
# sourced from po/POTFILES.in). Upstream links against gettext and calls
# Intl.bindtextdomain in src/main.vala; the Ruby bindings expose no gettext, so
# this reads the same .po files directly.
#
# The catalogue directory defaults to a `po` directory beside this checkout, so
# dropping upstream's po/ in place localises the port with no further wiring.
# With no catalogue for the current locale the msgid is the translation, which
# is exactly what gettext does.
#
module Translations
  DOMAIN = 'baobab'

  # Locale names are tried from most to least specific: pt_BR.UTF-8 resolves
  # pt_BR before pt, matching gettext's own lookup.
  module_function

  def gettext(msgid) = catalogue.fetch(key(msgid), [msgid]).first

  # Upstream's shortcuts dialog marks its strings with a "shortcuts dialog"
  # context, so those msgids need the context to resolve.
  def pgettext(context, msgid)
    catalogue.fetch(key(msgid, context), [msgid]).first
  end

  # Upstream's ngettext calls. The Germanic n != 1 rule is the one the msgids
  # are written against; a catalogue carrying its own Plural-Forms header
  # selects with that instead.
  def nplural(singular, plural, count)
    catalogue.fetch(key(singular), [singular, plural])
             .then { |forms| forms[plural_index(count, forms.length)] || plural }
  end

  # The locale the catalogue was loaded for, or nil when the strings are
  # untranslated. Reading it loads the catalogue, which is what decides it.
  def locale
    catalogue
    @locale
  end

  def catalogue_directory
    @catalogue_directory ||= File.expand_path('../po', __dir__)
  end

  # Tests and callers embedding the port point this at their own catalogues.
  def catalogue_directory=(path)
    @catalogue_directory = path
    reset
    path
  end

  def reset
    @catalogue = nil
    @locale = nil
  end

  def catalogue
    @catalogue ||= load_catalogue
  end

  def candidate_locales
    %w[LC_ALL LC_MESSAGES LANG]
      .filter_map { |name| ENV.fetch(name, nil) }
      .reject { |value| value.empty? || %w[C POSIX].include?(value) }
      .flat_map { |value| locale_variants(value) }
      .uniq
  end

  def locale_variants(value)
    value.split('.').first.then { |base| [base, base.split('_').first] }
  end

  def load_catalogue
    candidate_locales
      .lazy
      .map { |name| [name, File.join(catalogue_directory, "#{name}.po")] }
      .find { |_, path| File.file?(path) }
      .then { |found| found ? read_catalogue(*found) : {} }
  end

  def read_catalogue(name, path)
    @locale = name
    parse(File.read(path, encoding: 'UTF-8'))
  rescue SystemCallError, EncodingError => e
    warn "Could not read #{path}: #{e.message}"
    @locale = nil
    {}
  end

  # The key carries the msgctxt, because upstream's shortcut window strings use
  # the same msgid in more than one context.
  def key(msgid, context = nil) = context ? "#{context}\u0004#{msgid}" : msgid

  def plural_index(count, forms)
    case forms
    when ..1 then 0
    else count == 1 ? 0 : 1
    end
  end

  # A .po parser covering the constructs upstream's catalogues use: msgctxt,
  # msgid, msgid_plural, msgstr, indexed msgstr[n], continuation strings and
  # the C escapes inside them. Obsolete (#~) and fuzzy entries are skipped,
  # the same way gettext's runtime ignores them.
  def parse(source)
    source.each_line.with_object(parser_state) do |line, state|
      consume_line(line.chomp, state)
    end.then do |state|
      flush_entry(state)
      state[:entries]
    end
  end

  def parser_state
    {
      entries: {},
      context: nil,
      msgid:   nil,
      plurals: {},
      fuzzy:   false,
      field:   nil,
    }
  end

  def consume_line(line, state)
    case line
    when /\A#~/ then nil
    when /\A#,.*\bfuzzy\b/ then state[:fuzzy] = true
    when /\A#/ then nil
    when '' then flush_entry(state)
    when /\A msgctxt \s+ (".*") \z/x then start_field(state, :context, $1)
    when /\A msgid \s+ (".*") \z/x then start_msgid(state, $1)
    when /\A msgid_plural \s+ (".*") \z/x then start_field(state, :plural_id, $1)
    when /\A msgstr \s* \[ (\d+) \] \s+ (".*") \z/x then start_field(state, $1.to_i, $2)
    when /\A msgstr \s+ (".*") \z/x then start_field(state, 0, $1)
    when /\A (".*") \z/x then continue_field(state, $1)
    end
  end

  def start_msgid(state, literal)
    unless state[:msgid].nil?
      flush_entry(state)
    end
    start_field(state, :msgid, literal)
  end

  def start_field(state, field, literal)
    state[:field] = field
    write_field(state, field, unquote(literal))
  end

  def continue_field(state, literal)
    state[:field].then do |field|
      unless field.nil?
        write_field(state, field, (read_field(state, field) || '') + unquote(literal))
      end
    end
  end

  def write_field(state, field, value)
    case field
    when :context then state[:context] = value
    when :msgid then state[:msgid] = value
    when :plural_id then state[:plural_id] = value
    else state[:plurals][field] = value
    end
  end

  def read_field(state, field)
    case field
    when :context then state[:context]
    when :msgid then state[:msgid]
    when :plural_id then state[:plural_id]
    else state[:plurals][field]
    end
  end

  def flush_entry(state)
    translations = state[:plurals].sort_by(&:first).map(&:last)

    unless state[:msgid].nil? || state[:msgid].empty? || state[:fuzzy] || translations.all? { |t| t.to_s.empty? }
      state[:entries][key(state[:msgid], state[:context])] = translations
    end

    state.merge!(context: nil, msgid: nil, plural_id: nil, plurals: {}, fuzzy: false, field: nil)
  end

  ESCAPES = {
    '\\n'  => "\n",
    '\\t'  => "\t",
    '\\r'  => "\r",
    '\\"'  => '"',
    '\\\\' => '\\',
  }.freeze

  def unquote(literal)
    literal[1..-2].to_s.gsub(/\\[ntr"\\]/) { |escape| ESCAPES.fetch(escape, escape) }
  end
end
