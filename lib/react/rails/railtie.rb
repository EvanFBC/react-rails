require 'rails'
require 'open-uri'

module React
  module Rails
    class Railtie < ::Rails::Railtie
      config.react = ActiveSupport::OrderedOptions.new

      # Server-side rendering
      config.react.max_renderers = 10
      config.react.timeout = 20 #seconds
      config.react.component_filenames = ['OVERRIDE_WITH_SERVER_SIDE_PRERENDER_COMPONENTS_FILE.js']

      # Watch all JS files for any change, so we can reload the JS VMs with the new JS code.
      initializer "react_rails.add_watchable_files" do |app|
        app.config.watchable_files.concat Dir["#{app.root}/app/assets/javascripts/**/*"]
        app.config.watchable_files.concat Dir["#{app.root}/app/assets/webpack_output_prod/*.js"]
      end

      # Include the react-rails view helper lazily
      initializer "react_rails.setup_view_helpers" do
        ActiveSupport.on_load(:action_view) do
          include ::React::Rails::ViewHelper
        end
      end

      config.after_initialize do |app|
        # Server Rendering
        # Concat component_filenames together for server rendering
        app.config.react.components_js = lambda {
          app.config.react.component_filenames.map do |filename|
            begin
              c = open(filename) {|f| f.read }
            rescue Exception => e
              puts ["Error reading React server-side components file for prerendering.",
                    "Attempted to read: #{filename}",
                    "The file/url is configured in your app in `config.react.component_filenames`",
                    "",
                    "If you're in dev mode, verify `node webpack-dev-server.js` is running and serving webpack files",
                    "If you're in production, run `rake assets:precompile` so that the file is generated"
                   ].join("\n")
              raise e
            end
          end.join(";")
        }

        do_setup = lambda do
          cfg = app.config.react
          React::Renderer.setup!(cfg.components_js,
                                {:size => cfg.size, :timeout => cfg.timeout})
        end

        do_setup.call

        # Reload the JS VMs in dev when files change
        ActionDispatch::Reloader.to_prepare(&do_setup)
      end
    end
  end
end
