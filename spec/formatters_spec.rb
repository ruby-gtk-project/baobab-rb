# frozen_string_literal: true

require 'spec_helper'
require 'formatters'

RSpec.describe Formatters do
  describe '.format_size' do
    it 'formats a byte count' do
      expect(Formatters.format_size(1)).to eq(GLib.format_size(1))
    end

    it 'clamps a negative size to zero, as upstream never shows a negative' do
      expect(Formatters.format_size(-5)).to eq(GLib.format_size(0))
    end
  end

  describe '.format_items' do
    it 'pluralises one item on its own' do
      expect(Formatters.format_items(1)).to eq('1 item')
    end

    it 'pluralises more than one item' do
      expect(Formatters.format_items(3)).to eq('3 items')
    end

    it 'pluralises zero as the plural form' do
      expect(Formatters.format_items(0)).to eq('0 items')
    end
  end

  describe '.format_time_approximate' do
    it 'reads an unset time as Unknown' do
      expect(Formatters.format_time_approximate(0)).to eq('Unknown')
    end

    it 'reads a moment ago as Today' do
      expect(Formatters.format_time_approximate(Time.now.to_i)).to eq('Today')
    end

    it 'buckets a few days ago as days' do
      expect(Formatters.format_time_approximate(Time.now.to_i - (3 * Formatters::DAY))).to eq('3 days')
    end

    it 'buckets a single day ago in the singular' do
      expect(Formatters.format_time_approximate(Time.now.to_i - Formatters::DAY)).to eq('1 day')
    end

    it 'buckets a few months ago as months' do
      expect(Formatters.format_time_approximate(Time.now.to_i - (2 * Formatters::MONTH))).to eq('2 months')
    end

    it 'buckets a few years ago as years' do
      expect(Formatters.format_time_approximate(Time.now.to_i - (2 * Formatters::YEAR))).to eq('2 years')
    end
  end

  describe '.escape_markup' do
    it 'escapes the five Pango markup special characters' do
      expect(Formatters.escape_markup(%q(<a href="x">b & c's</a>)))
        .to eq('&lt;a href=&quot;x&quot;&gt;b &amp; c&apos;s&lt;/a&gt;')
    end

    it 'passes plain text through unchanged' do
      expect(Formatters.escape_markup('plain text')).to eq('plain text')
    end
  end
end
