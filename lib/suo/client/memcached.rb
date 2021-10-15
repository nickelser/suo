module Suo
  module Client
    class Memcached < Base
      def initialize(key, options = {})
        if !options[:client] && !defined?(::Dalli)
          raise "Dalli class not found. Please make sure you have 'dalli' as a dependency in your gemfile (`gem 'dalli'`)."
        end

        options[:client] ||= ::Dalli::Client.new(options[:connection] || ENV["MEMCACHE_SERVERS"] || "127.0.0.1:11211")
        super
      end

      def clear
        @client.with { |client| client.delete(@key) }
      end

      private

      def get
        @client.with { |client| client.get_cas(@key) }
      end

      def set(newval, cas, expire: false)
        if expire
          @client.with { |client| client.set_cas(@key, newval, cas, @options[:ttl]) }
        else
          @client.with { |client| client.set_cas(@key, newval, cas) }
        end
      end

      def initial_set(val = BLANK_STR)
        @client.with do |client|
          client.set(@key, val)
          _val, cas = client.get_cas(@key)
          cas
        end
      end
    end
  end
end
