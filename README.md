# Suo [![Build Status](https://travis-ci.org/nickelser/suo.svg?branch=master)](https://travis-ci.org/nickelser/suo) [![Code Climate](https://codeclimate.com/github/nickelser/suo/badges/gpa.svg)](https://codeclimate.com/github/nickelser/suo) [![Test Coverage](https://codeclimate.com/github/nickelser/suo/badges/coverage.svg)](https://codeclimate.com/github/nickelser/suo) [![Gem Version](https://badge.fury.io/rb/suo.svg)](http://badge.fury.io/rb/suo)

:lock: Distributed locks using Memcached or Redis in Ruby.

Suo provides a very performant distributed lock solution using Compare-And-Set (`CAS`) commands in Memcached, and `WATCH/MULTI` in Redis. It allows locking both single exclusion (a mutex - sharing one resource), and multiple resources.

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'suo'
```

## Usage

### Basic

```ruby
# Memcached
suo = Suo::Client::Memcached.new(connection: "127.0.0.1:11211")

# Redis
suo = Suo::Client::Redis.new(connection: {host: "10.0.1.1"})

# Pre-existing client
suo = Suo::Client::Memcached.new(client: some_dalli_client)

suo.lock("some_key") do
  # critical code here
  @puppies.pet!
end

# The second argument to lock is the number of arguments (defaulting to one - a mutex)
Thread.new { suo.lock("other_key", 2) { puts "One"; sleep 2 } }
Thread.new { suo.lock("other_key", 2) { puts "Two"; sleep 2 } }
Thread.new { suo.lock("other_key", 2) { puts "Three" } }

# will print "One" "Two", but not "Three", as there are only 2 resources

# custom acquisition timeouts (time to acquire)
suo = Suo::Client::Memcached.new(client: some_dalli_client, acquisition_timeout: 1) # in seconds

# manually locking/unlocking
# the return value from lock without a block is a unique token valid only for the current lock
# which must be unlocked manually
lock = suo.lock("a_key")
foo.baz!
suo.unlock("a_key", lock)

# custom stale lock expiration (cleaning of dead locks)
suo = Suo::Client::Redis.new(client: some_redis_client, stale_lock_expiration: 60*5)
```

### Stale locks

"Stale locks" - those acquired more than `stale_lock_expiration` (defaulting to 3600 or one hour) ago - are automatically cleared during any operation on the key (`lock`, `unlock`, `refresh`). The `locked?` method will not return true if only stale locks exist, but will not modify the key itself.

To re-acquire a lock in the middle of a block, you can use the refresh method on client.

```ruby
suo = Suo::Client::Redis.new

# lock is the same token as seen in the manual example, above
suo.lock("foo") do |lock|
  5.times do
    baz.bar!
    suo.refresh("foo", lock)
  end
end
```

## Semaphore

With multiple resources, Suo acts like a semaphore, but is not strictly a semaphore according to the traditional definition, as the lock acquires ownership.

## TODO
 - more race condition tests

## History

View the [changelog](https://github.com/nickelser/suo/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/nickelser/suo/issues)
- Fix bugs and [submit pull requests](https://github.com/nickelser/suo/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
