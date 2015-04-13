module Suo
  module Client
    class Redis < Base
      def initialize(options = {})
        options[:client] ||= ::Redis.new(options[:connection] || {})
        super
      end

      class << self
        def clear(key, options = {})
          options = merge_defaults(options)
          options[:client].del(key)
        end

        private

        def get(key, options)
          [options[:client].get(key), nil]
        end

        def set(key, newval, _, options)
          ret = options[:client].multi do |multi|
            multi.set(key, newval)
          end

          ret[0] == "OK"
        end

        def synchronize(key, options)
          options[:client].watch(key) do
            yield
          end
        ensure
          options[:client].unwatch
        end

        def set_initial(key, options)
          options[:client].set(key, "")
        end
      end
    end
  end
end
