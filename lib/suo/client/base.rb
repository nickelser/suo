module Suo
  module Client
    class Base
      DEFAULT_OPTIONS = {
        acquisition_timeout: 0.1,
        acquisition_delay: 0.01,
        stale_lock_expiration: 3600
      }.freeze

      attr_accessor :client

      include MonitorMixin

      def initialize(options = {})
        fail "Client required" unless options[:client]
        @options = DEFAULT_OPTIONS.merge(options)
        @retry_count = (@options[:acquisition_timeout] / @options[:acquisition_delay].to_f).ceil
        @client = @options[:client]
        super()
      end

      def lock(key, resources = 1)
        token = acquire_lock(key, resources)

        if block_given? && token
          begin
            yield(token)
          ensure
            unlock(key, token)
          end
        else
          token
        end
      end

      def locked?(key, resources = 1)
        locks(key).size >= resources
      end

      def locks(key)
        val, _ = get(key)
        cleared_locks = deserialize_and_clear_locks(val)

        cleared_locks
      end

      def refresh(key, acquisition_token)
        retry_with_timeout(key) do
          val, cas = get(key)

          if val.nil?
            initial_set(key)
            next
          end

          cleared_locks = deserialize_and_clear_locks(val)

          refresh_lock(cleared_locks, acquisition_token)

          break if set(key, serialize_locks(cleared_locks), cas)
        end
      end

      def unlock(key, acquisition_token)
        return unless acquisition_token

        retry_with_timeout(key) do
          val, cas = get(key)

          break if val.nil?

          cleared_locks = deserialize_and_clear_locks(val)

          acquisition_lock = remove_lock(cleared_locks, acquisition_token)

          break unless acquisition_lock
          break if set(key, serialize_locks(cleared_locks), cas)
        end
      rescue LockClientError => _ # rubocop:disable Lint/HandleExceptions
        # ignore - assume success due to optimistic locking
      end

      def clear(key) # rubocop:disable Lint/UnusedMethodArgument
        fail NotImplementedError
      end

      private

      def acquire_lock(key, resources = 1)
        acquisition_token = nil
        token = SecureRandom.base64(16)

        retry_with_timeout(key) do
          val, cas = get(key)

          if val.nil?
            initial_set(key)
            next
          end

          cleared_locks = deserialize_and_clear_locks(val)

          if cleared_locks.size < resources
            add_lock(cleared_locks, token)

            newval = serialize_locks(cleared_locks)

            if set(key, newval, cas)
              acquisition_token = token
              break
            end
          end
        end

        acquisition_token
      end

      def get(key) # rubocop:disable Lint/UnusedMethodArgument
        fail NotImplementedError
      end

      def set(key, newval, cas) # rubocop:disable Lint/UnusedMethodArgument
        fail NotImplementedError
      end

      def initial_set(key) # rubocop:disable Lint/UnusedMethodArgument
        fail NotImplementedError
      end

      def synchronize(key) # rubocop:disable Lint/UnusedMethodArgument
        mon_synchronize { yield }
      end

      def retry_with_timeout(key)
        start = Time.now.to_f

        @retry_count.times do
          now = Time.now.to_f
          break if now - start > @options[:acquisition_timeout]

          synchronize(key) do
            yield
          end

          sleep(rand(@options[:acquisition_delay] * 1000).to_f / 1000)
        end
      rescue => _
        raise LockClientError
      end

      def serialize_locks(locks)
        MessagePack.pack(locks.map { |time, token| [time.to_f, token] })
      end

      def deserialize_and_clear_locks(val)
        clear_expired_locks(deserialize_locks(val))
      end

      def deserialize_locks(val)
        unpacked = (val.nil? || val == "") ? [] : MessagePack.unpack(val)

        unpacked.map do |time, token|
          [Time.at(time), token]
        end
      rescue EOFError => _
        []
      end

      def clear_expired_locks(locks)
        expired = Time.now - @options[:stale_lock_expiration]
        locks.reject { |time, _| time < expired }
      end

      def add_lock(locks, token, time = Time.now.to_f)
        locks << [time, token]
      end

      def remove_lock(locks, acquisition_token)
        lock = locks.find { |_, token| token == acquisition_token }
        locks.delete(lock)
      end

      def refresh_lock(locks, acquisition_token)
        remove_lock(locks, acquisition_token)
        add_lock(locks, acquisition_token)
      end
    end
  end
end
