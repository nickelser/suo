## 0.4.0

- Monotonic clock for locks, avoiding issues with DST (thanks @doits)
- Pooled connection support (thanks @mlarraz)
- Switch to Github actions for tests (thanks @mlarraz)
- Update supported Ruby versions (thanks @mlarraz & @pat)

## 0.3.4

- Support for connection pooling when using memcached locks, via `with` blocks using Dalli (thanks to Lev).

## 0.3.3

- Default TTL for keys to allow for short-lived locking keys (thanks to Ian Remillard) without leaking memory.
- Vastly improve initial lock acquisition, especially on Redis (thanks to Jeremy Wadscak).

## 0.3.2

- Custom lock tokens (thanks to avokhmin).

## 0.3.1

- Slight memory leak fix.

## 0.3.0

- Dramatically simplify the interface by forcing clients to specify the key & resources at lock initialization instead of every method call.

## 0.2.3

- Clarify documentation further with respect to semaphores.

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
