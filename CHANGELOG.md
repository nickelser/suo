## 0.2.2

- Fix bug with refresh - typo would've prevented real use.
- Clean up code.
- Improve documentation a bit.
- 100% test coverage.

## 0.2.1

- Fix bug when dealing with real-world Redis error conditions.

## 0.2.0

- Refactor class methods into instance methods to simplify implementation.
- Increase thread safety with Memcached implementation.

## 0.1.3

- Properly throw Suo::LockClientError when the connection itself fails (Memcache server not reachable, etc.)

## 0.1.2

- Fix retry_timeout to properly use the full time (was being calculated incorrectly).
- Refactor client implementations to re-use more code.

## 0.1.1

- Use [MessagePack](https://github.com/msgpack/msgpack-ruby) for lock serialization.

## 0.1.0

- First release.
