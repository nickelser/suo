module Suo
  module Client
    class Memcached < Base
      def initialize(options = {})
        options[:client] ||= Dalli::Client.new(options[:connection] || ENV["MEMCACHE_SERVERS"] || "127.0.0.1:11211")
        super
      end

      class << self
        def clear(key, options = {})
          options = merge_defaults(options)
          options[:client].delete(key)
        end

        private

        def get(key, options)
          options[:client].get_cas(key)
        end

        def set(key, newval, cas, options)
          options[:client].set_cas(key, newval, cas)
        end

        def set_initial(key, options)
          options[:client].set(key, "")
        end
      end
    end
  end
end
