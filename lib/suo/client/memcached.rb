module Suo
  module Client
    class Memcached < Base
      def initialize(options = {})
        options[:client] ||= Dalli::Client.new(options[:connection] || ENV["MEMCACHE_SERVERS"] || "127.0.0.1:11211")
        super
      end

      def clear(key)
        @client.delete(key)
      end

      private

      def get(key)
        @client.get_cas(key)
      end

      def set(key, newval, cas)
        @client.set_cas(key, newval, cas)
      end

      def initial_set(key)
        @client.set(key, "")
      end
    end
  end
end
