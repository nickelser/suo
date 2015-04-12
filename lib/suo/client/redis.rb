module Suo
  module Client
    class Redis < Base
      def initialize(options = {})
        options[:client] ||= ::Redis.new(options[:connection] || {})
        super
      end

      class << self
        def lock(key, resources = 1, options = {})
          options = merge_defaults(options)
          acquisition_token = nil
          token = SecureRandom.base64(16)
          client = options[:client]

          begin
            start = Time.now.to_f

            options[:retry_count].times do
              if options[:retry_timeout]
                now = Time.now.to_f
                break if now - start > options[:retry_timeout]
              end

              client.watch(key) do
                begin
                  val = client.get(key)

                  locks = clear_expired_locks(deserialize_locks(val.to_s), options)

                  if locks.size < resources
                    add_lock(locks, token)

                    newval = serialize_locks(locks)

                    ret = client.multi do |multi|
                      multi.set(key, newval)
                    end

                    acquisition_token = token if ret[0] == "OK"
                  end
                ensure
                  client.unwatch
                end
              end

              break if acquisition_token

              sleep(rand(options[:retry_delay] * 1000).to_f / 1000)
            end
          rescue => _
            raise Suo::Client::FailedToAcquireLock
          end

          acquisition_token
        end

        def refresh(key, acquisition_token, options = {})
          options = merge_defaults(options)
          client = options[:client]
          refreshed = false

          begin
            start = Time.now.to_f

            options[:retry_count].times do
              if options[:retry_timeout]
                now = Time.now.to_f
                break if now - start > options[:retry_timeout]
              end

              client.watch(key) do
                begin
                  val = client.get(key)

                  locks = clear_expired_locks(deserialize_locks(val), options)

                  refresh_lock(locks, acquisition_token)

                  newval = serialize_locks(locks)

                  ret = client.multi do |multi|
                    multi.set(key, newval)
                  end

                  refreshed = ret[0] == "OK"
                ensure
                  client.unwatch
                end
              end

              break if refreshed

              sleep(rand(options[:retry_delay] * 1000).to_f / 1000)
            end
          rescue => _
            raise Suo::Client::FailedToAcquireLock
          end
        end

        def unlock(key, acquisition_token, options = {})
          options = merge_defaults(options)
          client = options[:client]

          return unless acquisition_token

          begin
            start = Time.now.to_f

            options[:retry_count].times do
              cleared = false

              if options[:retry_timeout]
                now = Time.now.to_f
                break if now - start > options[:retry_timeout]
              end

              client.watch(key) do
                begin
                  val = client.get(key)

                  if val.nil?
                    cleared = true
                    break
                  end

                  locks = clear_expired_locks(deserialize_locks(val), options)

                  acquisition_lock = remove_lock(locks, acquisition_token)

                  unless acquisition_lock
                    # token was already cleared
                    cleared = true
                    break
                  end

                  newval = serialize_locks(locks)

                  ret = client.multi do |multi|
                    multi.set(key, newval)
                  end

                  cleared = ret[0] == "OK"
                ensure
                  client.unwatch
                end
              end

              break if cleared

              sleep(rand(options[:retry_delay] * 1000).to_f / 1000)
            end
          rescue => boom # rubocop:disable Lint/HandleExceptions
            # since it's optimistic locking - fine if we are unable to release
            raise boom if ENV["SUO_TEST"]
          end
        end

        def clear(key, options = {})
          options = merge_defaults(options)
          options[:client].del(key)
        end
      end
    end
  end
end
