require 'connection_pool'

module React
  class Renderer

    class PrerenderError < RuntimeError
      def initialize(component_name, props, js_message)
        message = "Encountered error \"#{js_message}\" when prerendering #{component_name} with #{props}"
        super(message)
      end
    end

    cattr_accessor :pool

    def self.setup!(components_js, args={})
      args.assert_valid_keys(:size, :timeout)
      @@components_js = components_js
      @@pool.shutdown{} if @@pool
      reset_combined_js!
      default_pool_options = {:size =>10, :timeout => 20}
      @@pool = ConnectionPool.new(default_pool_options.merge(args)) { self.new }
    end

    def self.render(component, args={})
      @@pool.with do |renderer|
        renderer.render(component, args)
      end
    end

    def self.react_props(args={})
      if args.is_a? String
        args
      else
        args.to_json
      end
    end

    def context
      @context ||= ExecJS.compile(self.class.combined_js)
    end

    def render(component, args={})
      react_props = React::Renderer.react_props(args)
      jscode = <<-JS
        function() {
          return React.renderToString(React.createElement(#{component}, #{react_props}));
        }()
      JS
      context.eval(jscode).html_safe
    rescue ExecJS::ProgramError => e
      raise PrerenderError.new(component, react_props, e)
    end


    private

    def self.setup_combined_js
      components_js = @@components_js.call
      <<-CODE
        var global = global || this;
        var self = self || this;
        var window = window || this;

        var console = global.console || {};
        ['error', 'log', 'info', 'warn'].forEach(function (fn) {
          if (!(fn in console)) {
            console[fn] = function () {};
          }
        });

        #{components_js}
      CODE
    end

    def self.reset_combined_js!
      @@combined_js = setup_combined_js
    end

    def self.combined_js
      @@combined_js
    end

  end
end
