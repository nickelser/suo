module Suo
  module Client
    class Base
      DEFAULT_OPTIONS = {
        retry_count: 3,
        retry_delay: 0.01,
        stale_lock_expiration: 3600
      }.freeze

      def initialize(options = {})
        @options = self.class.merge_defaults(options).merge(_initialized: true)
      end

      def lock(key, resources = 1, options = {})
        options = self.class.merge_defaults(@options.merge(options))
        token = self.class.lock(key, resources, options)

        if token
          begin
            yield if block_given?
          ensure
            self.class.unlock(key, token, options)
          end

          true
        else
          false
        end
      end

      def locked?(key, resources = 1)
        self.class.locked?(key, resources, @options)
      end

      class << self
        def lock(key, resources = 1, options = {}) # rubocop:disable Lint/UnusedMethodArgument
          fail NotImplementedError
        end

        def locked?(key, resources = 1, options = {})
          options = merge_defaults(options)
          client = options[:client]
          locks = deserialize_locks(client.get(key))

          locks.size >= resources
        end

        def locks(key, options)
          options = merge_defaults(options)
          client = options[:client]
          locks = deserialize_locks(client.get(key))

          locks.size
        end

        def refresh(key, acquisition_token, options = {}) # rubocop:disable Lint/UnusedMethodArgument
          fail NotImplementedError
        end

        def unlock(key, acquisition_token, options = {}) # rubocop:disable Lint/UnusedMethodArgument
          fail NotImplementedError
        end

        def clear(key, options = {}) # rubocop:disable Lint/UnusedMethodArgument
          fail NotImplementedError
        end

        def merge_defaults(options = {})
          unless options[:_initialized]
            options = self::DEFAULT_OPTIONS.merge(options)

            fail "Client required" unless options[:client]
          end

          if options[:retry_timeout]
            options[:retry_count] = (options[:retry_timeout] / options[:retry_delay].to_f).floor
          end

          options
        end

        private

        def serialize_locks(locks)
          MessagePack.pack(locks.map { |time, token| [time.to_f, token] })
        end

        def deserialize_locks(val)
          MessagePack.unpack(val).map do |time, token|
            [Time.at(time), token]
          end
        rescue EOFError => _
          []
        end

        def clear_expired_locks(locks, options)
          expired = Time.now - options[:stale_lock_expiration]
          locks.reject { |time, _| time < expired }
        end

        def add_lock(locks, token)
          locks << [Time.now.to_f, token]
        end

        def remove_lock(locks, acquisition_token)
          lock = locks.find { |_, token| token == acquisition_token }
          locks.delete(lock)
        end

        def refresh_lock(locks, acquisition_token)
          remove_lock(locks, acquisition_token)
          add_lock(locks, token)
        end
      end
    end
  end
end
