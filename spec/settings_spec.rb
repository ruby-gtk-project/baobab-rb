# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'settings'

RSpec.describe Settings do
  let(:path) { File.join(Dir.mktmpdir('baobab-settings-spec'), 'settings.json') }
  let(:settings) { Settings.new(path: path) }

  describe 'defaults' do
    it 'defaults active-chart to rings' do
      expect(settings.active_chart).to eq('rings')
    end

    it 'defaults excluded-uris to empty' do
      expect(settings.excluded_uris).to eq([])
    end

    it 'defaults is-maximized to false' do
      expect(settings.is_maximized?).to be(false)
    end
  end

  describe '#active_chart' do
    it 'rejects a chart name outside the schema choices, falling back to the default' do
      settings['active-chart'] = 'pie'
      expect(settings.active_chart).to eq('rings')
    end

    it 'accepts a valid choice' do
      settings['active-chart'] = 'treemap'
      expect(settings.active_chart).to eq('treemap')
    end
  end

  describe '#add_excluded_uri and #remove_excluded_uri' do
    it 'adds a uri once' do
      settings.add_excluded_uri('file:///tmp/a')
      settings.add_excluded_uri('file:///tmp/a')
      expect(settings.excluded_uris).to eq(['file:///tmp/a'])
    end

    it 'removes a uri' do
      settings.add_excluded_uri('file:///tmp/a')
      settings.remove_excluded_uri('file:///tmp/a')
      expect(settings.excluded_uris).to eq([])
    end
  end

  describe 'persistence' do
    it 'round-trips a value through the backing file' do
      settings.add_excluded_uri('file:///tmp/b')
      reloaded = Settings.new(path: path)
      expect(reloaded.excluded_uris).to eq(['file:///tmp/b'])
    end

    it 'survives a corrupt file by falling back to defaults' do
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, 'not json')
      expect { Settings.new(path: path).active_chart }.not_to raise_error
    end
  end
end
