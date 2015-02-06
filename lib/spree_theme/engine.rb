module SpreeTheme
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_theme'

    config.autoload_paths += %W(#{config.root}/lib)

    # use rspec for tests
    config.generators do |g|
      g.test_framework :rspec
    end

    initializer :assets do |config|
      Rails.application.config.assets.precompile += %w( spree/theme/print.css select2_locale* bx_loader.gif controls.png )
      Rails.application.config.assets.precompile << %r(icons\.(?:eot|svg|ttf|woff)$)
#      Rails.application.config.assets.precompile += %w( enquire.js jquery.easydropdown.js jquery.hoverIntent.js jquery.bxslider.js matchMedia.js jquery.dotdotdot-1.5.2.js )
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare &method(:activate).to_proc
  end
end
