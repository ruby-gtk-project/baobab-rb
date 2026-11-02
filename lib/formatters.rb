# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

# Formatters holds the string formatting helpers the cells share.
#
# Ported from upstream's src/baobab-cellrenderers.vala, which is a pair of
# namespace-level functions (format_items and format_time_approximate) rather
# than a class. The size formatting upstream gets from GLib's format_size is
# here too, so every cell has one place to reach for.
#
module Formatters
  DAY = 86_400
  MONTH = 31 * DAY
  YEAR = 365 * DAY

  module_function

  # Byte counts, in the same SI units upstream's format_size produces.
  def format_size(size) = GLib.format_size(size.to_i.negative? ? 0 : size.to_i)

  # Upstream: ngettext ("%d item", "%d items", items).
  def format_items(items)
    Translations.nplural('%d item', '%d items', items.to_i) % items.to_i
  end

  # Upstream: format_time_approximate, which buckets an mtime into today,
  # days, months or years rather than printing a date.
  def format_time_approximate(time)
    seconds = time.to_i

    case seconds
    when 0 then Translations.gettext('Unknown')
    else approximate_age(Time.now.to_i - seconds)
    end
  end

  # Pango and tooltip markup is assembled by hand in a few places, and GLib's
  # markup_escape_text is not bound in the Ruby bindings.
  def escape_markup(text)
    text.to_s
        .gsub('&', '&amp;')
        .gsub('<', '&lt;')
        .gsub('>', '&gt;')
        .gsub('"', '&quot;')
        .gsub("'", '&apos;')
  end

  def approximate_age(elapsed)
    case elapsed
    when ...DAY then Translations.gettext('Today')
    when ...MONTH then plural_age('%lu day', '%lu days', elapsed / DAY)
    when ...YEAR then plural_age('%lu month', '%lu months', elapsed / MONTH)
    else plural_age('%lu year', '%lu years', elapsed / YEAR)
    end
  end

  # The %lu in upstream's msgids is a C length modifier Ruby's format does not
  # know, so the placeholder is swapped for %d before the substitution.
  def plural_age(singular, plural, count)
    Translations.nplural(singular, plural, count).gsub('%lu', '%d') % count
  end
end
