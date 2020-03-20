module Suo
  module Client
    class Redis < Base
      OK_STR = "OK".freeze

      def initialize(key, options = {})
        options[:client] ||= ::Redis.new(options[:connection] || {})
        super
      end

      def clear
        with { |r| r.del(@key) }
      end

      private

      def with(&block)
        if @client.respond_to?(:with)
          @client.with(&block)
        else
          yield @client
        end
      end

      def get
        [with { |r| r.get(@key) }, nil]
      end

      def set(newval, _, expire: false)
        ret = with do |r|
          r.multi do |rr|
            if expire
              rr.setex(@key, @options[:ttl], newval)
            else
              rr.set(@key, newval)
            end
          end
        end

        ret && ret[0] == OK_STR
      end

      def synchronize
        with { |r| r.watch(@key) { yield } }
      ensure
        with { |r| r.unwatch }
      end

      def initial_set(val = BLANK_STR)
        set(val, nil)
        nil
      end
    end
  end
end
