module Suo
  module Client
    class Memcached < Base
      def initialize(key, options = {})
        options[:client] ||= Dalli::Client.new(options[:connection] || ENV["MEMCACHE_SERVERS"] || "127.0.0.1:11211")
        super
      end

      def clear
        @client.delete(@key)
      end

      private

      def get
        @client.get_cas(@key)
      end

      def set(newval, cas, expire: false)
        if expire
          @client.set_cas(@key, newval, cas, @options[:ttl])
        else
          @client.set_cas(@key, newval, cas)
        end
      end

      def initial_set(val = BLANK_STR)
        @client.set(@key, val)
        _val, cas = @client.get_cas(@key)
        cas
      end
    end
  end
end
