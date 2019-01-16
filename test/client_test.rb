require "test_helper"

TEST_KEY = "suo_test_key".freeze

module ClientTests
  def client(options = {})
    @client.class.new(options[:key] || TEST_KEY, options.merge(client: @client.client))
  end

  def test_throws_failed_error_on_bad_client
    assert_raises(Suo::LockClientError) do
      client = @client.class.new(TEST_KEY, client: {})
      client.lock
    end
  end

  def test_single_resource_locking
    lock1 = @client.lock
    refute_nil lock1

    locked = @client.locked?
    assert_equal true, locked

    lock2 = @client.lock
    assert_nil lock2

    @client.unlock(lock1)

    locked = @client.locked?

    assert_equal false, locked
  end

  def test_lock_with_custom_token
    token = 'foo-bar'
    lock  = @client.lock token
    assert_equal lock, token
  end

  def test_empty_lock_on_invalid_data
    @client.send(:initial_set, "bad value")
    assert_equal false, @client.locked?
  end

  def test_raise_with_option_fail_without_lock
    @client = client(fail_without_lock: true)
    lock1 = @client.lock
    refute_nil lock1

    assert_raises(Suo::FailedLock) do
      @client.lock
    end
  end

  def test_clear
    lock1 = @client.lock
    refute_nil lock1

    @client.clear

    assert_equal false, @client.locked?
  end

  def test_multiple_resource_locking
    @client = client(resources: 2)

    lock1 = @client.lock
    refute_nil lock1

    assert_equal false, @client.locked?

    lock2 = @client.lock
    refute_nil lock2

    assert_equal true, @client.locked?

    @client.unlock(lock1)

    assert_equal false, @client.locked?

    assert_equal 1, @client.locks.size

    @client.unlock(lock2)

    assert_equal false, @client.locked?
    assert_equal 0, @client.locks.size
  end

  def test_block_single_resource_locking
    locked = false

    @client.lock { locked = true }

    assert_equal true, locked
  end

  def test_block_unlocks_on_exception
    assert_raises(RuntimeError) do
      @client.lock{ fail "Test" }
    end

    assert_equal false, @client.locked?
  end

  def test_readme_example
    output = Queue.new
    @client = client(resources: 2)
    threads = []

    threads << Thread.new { @client.lock { output << "One"; sleep 0.5 } }
    threads << Thread.new { @client.lock { output << "Two"; sleep 0.5 } }
    sleep 0.1
    threads << Thread.new { @client.lock { output << "Three" } }

    threads.each(&:join)

    ret = []

    ret << (output.size > 0 ? output.pop : nil)
    ret << (output.size > 0 ? output.pop : nil)

    ret.sort!

    assert_equal 0, output.size
    assert_equal %w(One Two), ret
    assert_equal false, @client.locked?
  end

  def test_block_multiple_resource_locking
    success_counter = Queue.new
    failure_counter = Queue.new

    @client = client(acquisition_timeout: 0.9, resources: 50)

    100.times.map do |i|
      Thread.new do
        success = @client.lock do
          sleep(3)
          success_counter << i
        end

        failure_counter << i unless success
      end
    end.each(&:join)

    assert_equal 50, success_counter.size
    assert_equal 50, failure_counter.size
    assert_equal false, @client.locked?
  end

  def test_block_multiple_resource_locking_longer_timeout
    success_counter = Queue.new
    failure_counter = Queue.new

    @client = client(acquisition_timeout: 3, resources: 50)

    100.times.map do |i|
      Thread.new do
        success = @client.lock do
          sleep(0.5)
          success_counter << i
        end

        failure_counter << i unless success
      end
    end.each(&:join)

    assert_equal 100, success_counter.size
    assert_equal 0, failure_counter.size
    assert_equal false, @client.locked?
  end

  def test_unstale_lock_acquisition
    success_counter = Queue.new
    failure_counter = Queue.new

    @client = client(stale_lock_expiration: 0.5)

    t1 = Thread.new { @client.lock { sleep 0.6; success_counter << 1 } }
    sleep 0.3
    t2 = Thread.new do
      locked = @client.lock { success_counter << 1 }
      failure_counter << 1 unless locked
    end

    [t1, t2].each(&:join)

    assert_equal 1, success_counter.size
    assert_equal 1, failure_counter.size
    assert_equal false, @client.locked?
  end

  def test_stale_lock_acquisition
    success_counter = Queue.new
    failure_counter = Queue.new

    @client = client(stale_lock_expiration: 0.5)

    t1 = Thread.new { @client.lock { sleep 0.6; success_counter << 1 } }
    sleep 0.55
    t2 = Thread.new do
      locked = @client.lock { success_counter << 1 }
      failure_counter << 1 unless locked
    end

    [t1, t2].each(&:join)

    assert_equal 2, success_counter.size
    assert_equal 0, failure_counter.size
    assert_equal false, @client.locked?
  end

  def test_refresh
    @client = client(stale_lock_expiration: 0.5)

    lock1 = @client.lock

    assert_equal true, @client.locked?

    @client.refresh(lock1)

    assert_equal true, @client.locked?

    sleep 0.55

    assert_equal false, @client.locked?

    lock2 = @client.lock

    @client.refresh(lock1)

    assert_equal true, @client.locked?

    @client.unlock(lock1)

    # edge case with refresh lock in the middle
    assert_equal true, @client.locked?

    @client.clear

    assert_equal false, @client.locked?

    @client.refresh(lock2)

    assert_equal true, @client.locked?

    @client.unlock(lock2)

    # now finally unlocked
    assert_equal false, @client.locked?
  end

  def test_block_refresh
    success_counter = Queue.new
    failure_counter = Queue.new

    @client = client(stale_lock_expiration: 0.5)

    t1 = Thread.new do
      @client.lock do |token|
        sleep 0.6
        @client.refresh(token)
        sleep 1
        success_counter << 1
      end
    end

    t2 = Thread.new do
      sleep 0.8
      locked = @client.lock { success_counter << 1 }
      failure_counter << 1 unless locked
    end

    [t1, t2].each(&:join)

    assert_equal 1, success_counter.size
    assert_equal 1, failure_counter.size
    assert_equal false, @client.locked?
  end

  def test_refresh_multi
    success_counter = Queue.new
    failure_counter = Queue.new

    @client = client(stale_lock_expiration: 0.5, resources: 2)

    t1 = Thread.new do
      @client.lock do |token|
        sleep 0.4
        @client.refresh(token)
        success_counter << 1
        sleep 0.5
      end
    end

    t2 = Thread.new do
      sleep 0.55
      locked = @client.lock do
        success_counter << 1
        sleep 0.5
      end

      failure_counter << 1 unless locked
    end

    t3 = Thread.new do
      sleep 0.75
      locked = @client.lock { success_counter << 1 }
      failure_counter << 1 unless locked
    end

    [t1, t2, t3].each(&:join)

    assert_equal 2, success_counter.size
    assert_equal 1, failure_counter.size
    assert_equal false, @client.locked?
  end

  def test_increment_reused_client
    i = 0

    threads = 2.times.map do
      Thread.new do
        @client.lock { i += 1 }
      end
    end

    threads.each(&:join)

    assert_equal 2, i
    assert_equal false, @client.locked?
  end

  def test_increment_new_client
    i = 0

    threads = 2.times.map do
      Thread.new do
        # note this is the method that generates a *new* client
        client.lock { i += 1 }
      end
    end

    threads.each(&:join)

    assert_equal 2, i
    assert_equal false, @client.locked?
  end
end

class TestBaseClient < Minitest::Test
  def setup
    @client = Suo::Client::Base.new(TEST_KEY, client: {})
  end

  def test_not_implemented
    assert_raises(NotImplementedError) do
      @client.send(:get)
    end

    assert_raises(NotImplementedError) do
      @client.send(:set, "", "")
    end

    assert_raises(NotImplementedError) do
      @client.send(:initial_set)
    end

    assert_raises(NotImplementedError) do
      @client.send(:clear)
    end
  end
end

class TestMemcachedClient < Minitest::Test
  include ClientTests

  def setup
    @dalli = Dalli::Client.new("127.0.0.1:11211")
    @client = Suo::Client::Memcached.new(TEST_KEY)
    teardown
  end

  def teardown
    @dalli.delete(TEST_KEY)
  end
end

class TestRedisClient < Minitest::Test
  include ClientTests

  def setup
    @redis = Redis.new
    @client = Suo::Client::Redis.new(TEST_KEY)
    teardown
  end

  def teardown
    @redis.del(TEST_KEY)
  end
end

class TestLibrary < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Suo::VERSION
  end
end
