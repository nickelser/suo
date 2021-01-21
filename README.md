# Suo [![Build Status](https://github.com/nickelser/suo/workflows/CI/badge.svg)](https://github.com/nickelser/suo/actions?query=workflow%3ACI) [![Code Climate](https://codeclimate.com/github/nickelser/suo/badges/gpa.svg)](https://codeclimate.com/github/nickelser/suo) [![Gem Version](https://badge.fury.io/rb/suo.svg)](http://badge.fury.io/rb/suo)

:lock: Distributed semaphores using Memcached or Redis in Ruby.

Suo provides a very performant distributed lock solution using Compare-And-Set (`CAS`) commands in Memcached, and `WATCH/MULTI` in Redis. It allows locking both single exclusion (like a mutex - sharing one resource), as well as multiple resources.

## Installation

Add this line to your application’s Gemfile:

```ruby
gem 'suo'
```

## Usage

### Basic

```ruby
# Memcached
suo = Suo::Client::Memcached.new("foo_resource", connection: "127.0.0.1:11211")

# Redis
suo = Suo::Client::Redis.new("baz_resource", connection: {host: "10.0.1.1"})

# Pre-existing client
suo = Suo::Client::Memcached.new("bar_resource", client: some_dalli_client)

suo.lock do
  # critical code here
  @puppies.pet!
end

# The resources argument is the number of resources the semaphore will allow to lock (defaulting to one - a mutex)
suo = Suo::Client::Memcached.new("bar_resource", client: some_dalli_client, resources: 2)

Thread.new { suo.lock { puts "One"; sleep 2 } }
Thread.new { suo.lock { puts "Two"; sleep 2 } }
Thread.new { suo.lock { puts "Three" } }

# will print "One" "Two", but not "Three", as there are only 2 resources

# custom acquisition timeouts (time to acquire)
suo = Suo::Client::Memcached.new("protected_key", client: some_dalli_client, acquisition_timeout: 1) # in seconds

# manually locking/unlocking
# the return value from lock without a block is a unique token valid only for the current lock
# which must be unlocked manually
token = suo.lock
foo.baz!
suo.unlock(token)

# custom stale lock expiration (cleaning of dead locks)
suo = Suo::Client::Redis.new("other_key", client: some_redis_client, stale_lock_expiration: 60*5)
```

### Stale locks

"Stale locks" - those acquired more than `stale_lock_expiration` (defaulting to 3600 or one hour) ago - are automatically cleared during any operation on the key (`lock`, `unlock`, `refresh`). The `locked?` method will not return true if only stale locks exist, but will not modify the key itself.

To re-acquire a lock in the middle of a block, you can use the refresh method on client.

```ruby
suo = Suo::Client::Redis.new("foo")

# lock is the same token as seen in the manual example, above
suo.lock do |token|
  5.times do
    baz.bar!
    suo.refresh(token)
  end
end
```

### Time To Live

```ruby
Suo::Client::Redis.new("bar_resource", ttl: 60) #ttl in seconds
```

A key representing a set of lockable resources is removed once the last resource lock is released and the `ttl` time runs out. When another lock is acquired and the key has been removed the key has to be recreated.


## TODO
 - more race condition tests

## History

View the [changelog](https://github.com/nickelser/suo/blob/master/CHANGELOG.md).

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/nickelser/suo/issues)
- Fix bugs and [submit pull requests](https://github.com/nickelser/suo/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
