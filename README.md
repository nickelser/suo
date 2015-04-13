# Suo [![Build Status](https://travis-ci.org/nickelser/suo.svg?branch=master)](https://travis-ci.org/nickelser/suo) [![Gem Version](https://badge.fury.io/rb/suo.svg)](http://badge.fury.io/rb/suo)

:lock: Distributed semaphores using Memcached or Redis in Ruby.

Suo provides a very performant distributed lock solution using Compare-And-Set (`CAS`) commands in Memcached, and `WATCH/MULTI` in Redis.

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

2.times do
  Thread.new do
    # second argument is the number of resources - so this will run twice
    suo.lock("other_key", 2, timeout: 0.5) { puts "Will run twice!" }
  end
end
```

## TODO
 - better stale key handling (refresh blocks)
 - more race condition tests
 - refactor clients to re-use more code

## History

View the [changelog](https://github.com/nickelser/suo/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/nickelser/suo/issues)
- Fix bugs and [submit pull requests](https://github.com/nickelser/suo/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
