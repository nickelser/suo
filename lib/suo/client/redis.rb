module Suo
  module Client
    class Redis < Base
      OK_STR = "OK".freeze

      def initialize(key, options = {})
        options[:client] ||= ::Redis.new(options[:connection] || {})
        super
      end

      def clear
        @client.del(@key)
      end

      private

      def get
        [@client.get(@key), nil]
      end

      def set(newval, _, expire:)
        ret = @client.multi do |multi|
          if expire
            multi.setex(@key, @options[:ttl], newval)
          else
            multi.set(@key, newval)
          end
        end

        ret && ret[0] == OK_STR
      end

      def synchronize
        @client.watch(@key) do
          yield
        end
      ensure
        @client.unwatch
      end

      def initial_set(val = BLANK_STR)
        @client.set(@key, val)
      end
    end
  end
end
