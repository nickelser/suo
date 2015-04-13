module Suo
  module Client
    class Redis < Base
      def initialize(options = {})
        options[:client] ||= ::Redis.new(options[:connection] || {})
        super
      end

      def clear(key)
        @client.del(key)
      end

      private

      def get(key)
        [@client.get(key), nil]
      end

      def set(key, newval, _)
        ret = @client.multi do |multi|
          multi.set(key, newval)
        end

        ret[0] == "OK"
      end

      def synchronize(key)
        @client.watch(key) do
          yield
        end
      ensure
        @client.unwatch
      end

      def set_initial(key)
        @client.set(key, "")
      end
    end
  end
end
