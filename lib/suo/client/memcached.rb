module Suo
  module Client
    class Memcached < Base
      def initialize(options = {})
        options[:client] ||= Dalli::Client.new(options[:connection] || ENV["MEMCACHE_SERVERS"] || "127.0.0.1:11211")
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

            options[:retry_count].times do |i|
              val, cas = client.get_cas(key)

              # no key has been set yet; we could simply set it, but would lead to race conditions on the initial setting
              if val.nil?
                client.set(key, "")
                next
              end

              locks = clear_expired_locks(deserialize_locks(val.to_s), options)

              if locks.size < resources
                add_lock(locks, token)

                newval = serialize_locks(locks)

                if client.set_cas(key, newval, cas)
                  acquisition_token = token
                  break
                end
              end

              if options[:retry_timeout]
                now = Time.now.to_f
                break if now - start > options[:retry_timeout]
              end

              sleep(rand(options[:retry_delay] * 1000).to_f / 1000)
            end
          rescue => _
            raise FailedToAcquireLock
          end

          acquisition_token
        end

        def refresh(key, acquisition_token, options = {})
          options = merge_defaults(options)
          client = options[:client]

          begin
            start = Time.now.to_f

            options[:retry_count].times do
              val, cas = client.get_cas(key)

              # much like with initial set - ensure the key is here
              if val.nil?
                client.set(key, "")
                next
              end

              locks = clear_expired_locks(deserialize_locks(val), options)

              refresh_lock(locks, acquisition_token)

              newval = serialize_locks(locks)

              break if client.set_cas(key, newval, cas)

              if options[:retry_timeout]
                now = Time.now.to_f
                break if now - start > options[:retry_timeout]
              end

              sleep(rand(options[:retry_delay] * 1000).to_f / 1000)
            end
          rescue => _
            raise FailedToAcquireLock
          end
        end

        def unlock(key, acquisition_token, options = {})
          options = merge_defaults(options)
          client = options[:client]

          return unless acquisition_token

          begin
            start = Time.now.to_f

            options[:retry_count].times do
              val, cas = client.get_cas(key)

              break if val.nil? # lock has expired totally

              locks = clear_expired_locks(deserialize_locks(val), options)

              acquisition_lock = remove_lock(locks, acquisition_token)

              break unless acquisition_lock

              newval = serialize_locks(locks)

              break if client.set_cas(key, newval, cas)

              # another client cleared a token in the interim - try again!

              if options[:retry_timeout]
                now = Time.now.to_f
                break if now - start > options[:retry_timeout]
              end

              sleep(rand(options[:retry_delay] * 1000).to_f / 1000)
            end
          rescue => boom # rubocop:disable Lint/HandleExceptions
            # since it's optimistic locking - fine if we are unable to release
            raise boom if ENV["SUO_TEST"]
          end
        end

        def clear(key, options = {})
          options = merge_defaults(options)
          options[:client].delete(key)
        end
      end
    end
  end
end
