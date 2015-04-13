module Suo
  module Client
    class Base
      DEFAULT_OPTIONS = {
        retry_timeout: 0.1,
        retry_delay: 0.01,
        stale_lock_expiration: 3600
      }.freeze

      def initialize(options = {})
        @options = self.class.merge_defaults(options)
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
        def lock(key, resources = 1, options = {})
          options = merge_defaults(options)
          acquisition_token = nil
          token = SecureRandom.base64(16)

          retry_with_timeout(key, options) do
            val, cas = get(key, options)

            if val.nil?
              set_initial(key, options)
              next
            end

            locks = deserialize_and_clear_locks(val, options)

            if locks.size < resources
              add_lock(locks, token)

              newval = serialize_locks(locks)

              if set(key, newval, cas, options)
                acquisition_token = token
                break
              end
            end
          end

          acquisition_token
        end

        def locked?(key, resources = 1, options = {})
          locks(key, options).size >= resources
        end

        def locks(key, options)
          options = merge_defaults(options)
          val, _ = get(key, options)
          locks = deserialize_locks(val)

          locks
        end

        def refresh(key, acquisition_token, options = {})
          options = merge_defaults(options)

          retry_with_timeout(key, options) do
            val, cas = get(key, options)

            if val.nil?
              set_initial(key, options)
              next
            end

            locks = deserialize_and_clear_locks(val, options)

            refresh_lock(locks, acquisition_token)

            break if set(key, serialize_locks(locks), cas, options)
          end
        end

        def unlock(key, acquisition_token, options = {})
          options = merge_defaults(options)

          return unless acquisition_token

          retry_with_timeout(key, options) do
            val, cas = get(key, options)

            break if val.nil?

            locks = deserialize_and_clear_locks(val, options)

            acquisition_lock = remove_lock(locks, acquisition_token)

            break unless acquisition_lock
            break if set(key, serialize_locks(locks), cas, options)
          end
        rescue FailedToAcquireLock => _ # rubocop:disable Lint/HandleExceptions
          # ignore - assume success due to optimistic locking
        end

        def clear(key, options = {}) # rubocop:disable Lint/UnusedMethodArgument
          fail NotImplementedError
        end

        def merge_defaults(options = {})
          options = self::DEFAULT_OPTIONS.merge(options)

          fail "Client required" unless options[:client]

          options[:retry_count] = (options[:retry_timeout] / options[:retry_delay].to_f).ceil

          options
        end

        private

        def get(key, options) # rubocop:disable Lint/UnusedMethodArgument
          fail NotImplementedError
        end

        def set(key, newval, oldval, options) # rubocop:disable Lint/UnusedMethodArgument
          fail NotImplementedError
        end

        def set_initial(key, options) # rubocop:disable Lint/UnusedMethodArgument
          fail NotImplementedError
        end

        def synchronize(key, options)
          yield(key, options)
        end

        def retry_with_timeout(key, options)
          start = Time.now.to_f

          options[:retry_count].times do
            if options[:retry_timeout]
              now = Time.now.to_f
              break if now - start > options[:retry_timeout]
            end

            synchronize(key, options) do
              yield
            end

            sleep(rand(options[:retry_delay] * 1000).to_f / 1000)
          end
        rescue => _
          raise FailedToAcquireLock
        end

        def serialize_locks(locks)
          MessagePack.pack(locks.map { |time, token| [time.to_f, token] })
        end

        def deserialize_and_clear_locks(val, options)
          clear_expired_locks(deserialize_locks(val), options)
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
