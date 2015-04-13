require "test_helper"

TEST_KEY = "suo_test_key".freeze

module ClientTests
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
  end

  def test_block_multiple_resource_locking
    success_counter = Queue.new
    failure_counter = Queue.new

    client = @client.class.new(acquisition_timeout: 0.9, client: @client.client)

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
  end

  def test_block_multiple_resource_locking_longer_timeout
    success_counter = Queue.new
    failure_counter = Queue.new

    client = @client.class.new(acquisition_timeout: 3, client: @client.client)

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
  end
end

class TestMemcachedClient < Minitest::Test
  include ClientTests

  def setup
    @dalli = Dalli::Client.new("127.0.0.1:11211")
    @client = Suo::Client::Memcached.new
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
