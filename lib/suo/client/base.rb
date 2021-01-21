module Suo
  module Client
    class Base
      DEFAULT_OPTIONS = {
        acquisition_timeout: 0.1,
        acquisition_delay: 0.01,
        stale_lock_expiration: 3600,
        resources: 1,
        ttl: 60,
      }.freeze

      BLANK_STR = "".freeze

      attr_accessor :client, :key, :resources, :options

      include MonitorMixin

      def initialize(key, options = {})
        fail "Client required" unless options[:client]

        @options = DEFAULT_OPTIONS.merge(options)
        @retry_count = (@options[:acquisition_timeout] / @options[:acquisition_delay].to_f).ceil
        @client = @options[:client]
        @resources = @options[:resources].to_i
        @key = key

        super() # initialize Monitor mixin for thread safety
      end

      def lock(custom_token = nil)
        token = acquire_lock(custom_token)

        if block_given? && token
          begin
            yield
          ensure
            unlock(token)
          end
        else
          token
        end
      end

      def locked?
        locks.size >= resources
      end

      def locks
        val, _ = get
        cleared_locks = deserialize_and_clear_locks(val)

        cleared_locks
      end

      def refresh(token)
        retry_with_timeout do
          val, cas = get

          cas = initial_set if val.nil?

          cleared_locks = deserialize_and_clear_locks(val)

          refresh_lock(cleared_locks, token)

          break if set(serialize_locks(cleared_locks), cas, expire: cleared_locks.empty?)
        end
      end

      def unlock(token)
        return unless token

        retry_with_timeout do
          val, cas = get

          break if val.nil?

          cleared_locks = deserialize_and_clear_locks(val)

          acquisition_lock = remove_lock(cleared_locks, token)

          break unless acquisition_lock
          break if set(serialize_locks(cleared_locks), cas, expire: cleared_locks.empty?)
        end
      rescue LockClientError => _ # rubocop:disable Lint/HandleExceptions
        # ignore - assume success due to optimistic locking
      end

      def clear
        fail NotImplementedError
      end

      private

      attr_accessor :retry_count

      def acquire_lock(token = nil)
        token ||= SecureRandom.base64(16)

        retry_with_timeout do
          val, cas = get

          cas = initial_set if val.nil?

          cleared_locks = deserialize_and_clear_locks(val)

          if cleared_locks.size < resources
            add_lock(cleared_locks, token)

            newval = serialize_locks(cleared_locks)

            return token if set(newval, cas)
          end
        end

        nil
      end

      def get
        fail NotImplementedError
      end

      def set(newval, cas) # rubocop:disable Lint/UnusedMethodArgument
        fail NotImplementedError
      end

      def initial_set(val = BLANK_STR) # rubocop:disable Lint/UnusedMethodArgument
        fail NotImplementedError
      end

      def synchronize
        mon_synchronize { yield }
      end

      def retry_with_timeout
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        retry_count.times do
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
          break if elapsed >= options[:acquisition_timeout]

          synchronize do
            yield
          end

          sleep(rand(options[:acquisition_delay] * 1000).to_f / 1000)
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
        unpacked = (val.nil? || val == BLANK_STR) ? [] : MessagePack.unpack(val)

        unpacked.map do |time, token|
          [Time.at(time), token]
        end
      rescue EOFError, MessagePack::MalformedFormatError => _
        []
      end

      def clear_expired_locks(locks)
        expired = Time.now - options[:stale_lock_expiration]
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
