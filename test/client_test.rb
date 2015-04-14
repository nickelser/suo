require "test_helper"

TEST_KEY = "suo_test_key".freeze

module ClientTests
  def client(options)
    @client.class.new(options.merge(client: @client.client))
  end

  def test_throws_failed_error_on_bad_client
    assert_raises(Suo::LockClientError) do
      client = @client.class.new(client: {})
      client.lock(TEST_KEY, 1)
    end
  end

  def test_single_resource_locking
    lock1 = @client.lock(TEST_KEY, 1)
    refute_nil lock1

    locked = @client.locked?(TEST_KEY, 1)
    assert_equal true, locked

    lock2 = @client.lock(TEST_KEY, 1)
    assert_nil lock2

    @client.unlock(TEST_KEY, lock1)

    locked = @client.locked?(TEST_KEY, 1)

    assert_equal false, locked
  end

  def test_clear
    lock1 = @client.lock(TEST_KEY, 1)
    refute_nil lock1

    @client.clear(TEST_KEY)

    locked = @client.locked?(TEST_KEY, 1)

    assert_equal false, locked
  end

  def test_multiple_resource_locking
    lock1 = @client.lock(TEST_KEY, 2)
    refute_nil lock1

    locked = @client.locked?(TEST_KEY, 2)
    assert_equal false, locked

    lock2 = @client.lock(TEST_KEY, 2)
    refute_nil lock2

    locked = @client.locked?(TEST_KEY, 2)
    assert_equal true, locked

    @client.unlock(TEST_KEY, lock1)

    locked = @client.locked?(TEST_KEY, 1)
    assert_equal true, locked

    @client.unlock(TEST_KEY, lock2)

    locked = @client.locked?(TEST_KEY, 1)
    assert_equal false, locked
  end

  def test_block_single_resource_locking
    locked = false

    @client.lock(TEST_KEY, 1) { locked = true }

    assert_equal true, locked
  end

  def test_block_unlocks_on_exception
    assert_raises(RuntimeError) do
      @client.lock(TEST_KEY, 1) { fail "Test" }
    end

    locked = @client.locked?(TEST_KEY, 1)
    assert_equal false, locked
  end

  def test_readme_example
    output = Queue.new
    threads = []

    threads << Thread.new { @client.lock(TEST_KEY, 2) { output << "One"; sleep 0.5 } }
    threads << Thread.new { @client.lock(TEST_KEY, 2) { output << "Two"; sleep 0.5 } }
    sleep 0.1
    threads << Thread.new { @client.lock(TEST_KEY, 2) { output << "Three" } }

    threads.map(&:join)

    ret = []

    ret << output.pop
    ret << output.pop

    ret.sort!

    assert_equal 0, output.size
    assert_equal %w(One Two), ret
    assert_equal false, @client.locked?(TEST_KEY)
  end

  def test_block_multiple_resource_locking
    success_counter = Queue.new
    failure_counter = Queue.new

    client = client(acquisition_timeout: 0.9)

    100.times.map do |i|
      Thread.new do
        success = client.lock(TEST_KEY, 50) do
          sleep(3)
          success_counter << i
        end

        failure_counter << i unless success
      end
    end.map(&:join)

    assert_equal 50, success_counter.size
    assert_equal 50, failure_counter.size
    assert_equal false, client.locked?(TEST_KEY)
  end

  def test_block_multiple_resource_locking_longer_timeout
    success_counter = Queue.new
    failure_counter = Queue.new

    client = client(acquisition_timeout: 3)

    100.times.map do |i|
      Thread.new do
        success = client.lock(TEST_KEY, 50) do
          sleep(0.5)
          success_counter << i
        end

        failure_counter << i unless success
      end
    end.map(&:join)

    assert_equal 100, success_counter.size
    assert_equal 0, failure_counter.size
    assert_equal false, client.locked?(TEST_KEY)
  end

  def test_unstale_lock_acquisition
    success_counter = Queue.new
    failure_counter = Queue.new

    client = client(stale_lock_expiration: 0.5)

    t1 = Thread.new { client.lock(TEST_KEY) { sleep 0.6; success_counter << 1 } }
    sleep 0.3
    t2 = Thread.new do
      locked = client.lock(TEST_KEY) { success_counter << 1 }
      failure_counter << 1 unless locked
    end

    [t1, t2].map(&:join)

    assert_equal 1, success_counter.size
    assert_equal 1, failure_counter.size
    assert_equal false, client.locked?(TEST_KEY)
  end

  def test_stale_lock_acquisition
    success_counter = Queue.new
    failure_counter = Queue.new

    client = client(stale_lock_expiration: 0.5)

    t1 = Thread.new { client.lock(TEST_KEY) { sleep 0.6; success_counter << 1 } }
    sleep 0.55
    t2 = Thread.new do
      locked = client.lock(TEST_KEY) { success_counter << 1 }
      failure_counter << 1 unless locked
    end

    [t1, t2].map(&:join)

    assert_equal 2, success_counter.size
    assert_equal 0, failure_counter.size
    assert_equal false, client.locked?(TEST_KEY)
  end

  def test_refresh
    client = client(stale_lock_expiration: 0.5)

    lock1 = client.lock(TEST_KEY)

    assert_equal true, client.locked?(TEST_KEY)

    client.refresh(TEST_KEY, lock1)

    assert_equal true, client.locked?(TEST_KEY)

    sleep 0.55

    assert_equal false, client.locked?(TEST_KEY)

    lock2 = client.lock(TEST_KEY)

    client.refresh(TEST_KEY, lock1)

    assert_equal true, client.locked?(TEST_KEY)

    client.unlock(TEST_KEY, lock1)

    # edge case with refresh lock in the middle
    assert_equal true, client.locked?(TEST_KEY)

    client.unlock(TEST_KEY, lock2)

    # now finally unlocked
    assert_equal false, client.locked?(TEST_KEY)
  end

  def test_block_refresh
    success_counter = Queue.new
    failure_counter = Queue.new

    client = client(stale_lock_expiration: 0.5)

    t1 = Thread.new do
      client.lock(TEST_KEY) do |token|
        sleep 0.6
        client.refresh(TEST_KEY, token)
        sleep 1
        success_counter << 1
      end
    end

    t2 = Thread.new do
      sleep 0.8
      locked = client.lock(TEST_KEY) { success_counter << 1 }
      failure_counter << 1 unless locked
    end

    [t1, t2].map(&:join)

    assert_equal 1, success_counter.size
    assert_equal 1, failure_counter.size
    assert_equal false, client.locked?(TEST_KEY)
  end

  def test_refresh_multi
    success_counter = Queue.new
    failure_counter = Queue.new

    client = client(stale_lock_expiration: 0.5)

    t1 = Thread.new do
      client.lock(TEST_KEY, 2) do |token|
        sleep 0.4
        client.refresh(TEST_KEY, token)
        success_counter << 1
        sleep 0.5
      end
    end

    t2 = Thread.new do
      sleep 0.55
      locked = client.lock(TEST_KEY, 2) do
        success_counter << 1
        sleep 0.5
      end

      failure_counter << 1 unless locked
    end

    t3 = Thread.new do
      sleep 0.75
      locked = client.lock(TEST_KEY, 2) { success_counter << 1 }
      failure_counter << 1 unless locked
    end

    [t1, t2, t3].map(&:join)

    assert_equal 2, success_counter.size
    assert_equal 1, failure_counter.size
    assert_equal false, client.locked?(TEST_KEY)
  end
end

class TestBaseClient < Minitest::Test
  def setup
    @client = Suo::Client::Base.new(client: {})
  end

  def test_not_implemented
    assert_raises(NotImplementedError) do
      @client.send(:get, TEST_KEY)
    end

    assert_raises(NotImplementedError) do
      @client.send(:set, TEST_KEY, "", "")
    end

    assert_raises(NotImplementedError) do
      @client.send(:initial_set, TEST_KEY)
    end

    assert_raises(NotImplementedError) do
      @client.send(:clear, TEST_KEY)
    end
  end
end

class TestMemcachedClient < Minitest::Test
  include ClientTests

  def setup
    @dalli = Dalli::Client.new("127.0.0.1:11211")
    @client = Suo::Client::Memcached.new
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
    @client = Suo::Client::Redis.new
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
