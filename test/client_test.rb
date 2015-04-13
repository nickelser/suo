require "test_helper"

TEST_KEY = "suo_test_key".freeze

module ClientTests
  def test_requires_client
    exception = assert_raises(RuntimeError) do
      @klass.lock(TEST_KEY, 1)
    end

    assert_equal "Client required", exception.message
  end

  def test_throws_failed_error_on_bad_client
    assert_raises(Suo::LockClientError) do
      @klass.lock(TEST_KEY, 1, client: {})
    end
  end

  def test_class_single_resource_locking
    lock1 = @klass.lock(TEST_KEY, 1, client: @klass_client)
    refute_nil lock1

    locked = @klass.locked?(TEST_KEY, 1, client: @klass_client)
    assert_equal true, locked

    lock2 = @klass.lock(TEST_KEY, 1, client: @klass_client)
    assert_nil lock2

    @klass.unlock(TEST_KEY, lock1, client: @klass_client)

    locked = @klass.locked?(TEST_KEY, 1, client: @klass_client)

    assert_equal false, locked
  end

  def test_class_multiple_resource_locking
    lock1 = @klass.lock(TEST_KEY, 2, client: @klass_client)
    refute_nil lock1

    locked = @klass.locked?(TEST_KEY, 2, client: @klass_client)
    assert_equal false, locked

    lock2 = @klass.lock(TEST_KEY, 2, client: @klass_client)
    refute_nil lock2

    locked = @klass.locked?(TEST_KEY, 2, client: @klass_client)
    assert_equal true, locked

    @klass.unlock(TEST_KEY, lock1, client: @klass_client)

    locked = @klass.locked?(TEST_KEY, 1, client: @klass_client)
    assert_equal true, locked

    @klass.unlock(TEST_KEY, lock2, client: @klass_client)

    locked = @klass.locked?(TEST_KEY, 1, client: @klass_client)
    assert_equal false, locked
  end

  def test_instance_single_resource_locking
    locked = false

    @client.lock(TEST_KEY, 1) { locked = true }

    assert_equal true, locked
  end

  def test_instance_unlocks_on_exception
    assert_raises(RuntimeError) do
      @client.lock(TEST_KEY, 1) { fail "Test" }
    end

    locked = @klass.locked?(TEST_KEY, 1, client: @klass_client)
    assert_equal false, locked
  end

  def test_instance_multiple_resource_locking
    success_counter = Queue.new
    failure_counter = Queue.new

    50.times.map do |i|
      Thread.new do
        success = @client.lock(TEST_KEY, 25, retry_timeout: 0.9) do
          sleep(3)
          success_counter << i
        end

        failure_counter << i unless success
      end
    end.map(&:join)

    assert_equal 25, success_counter.size
    assert_equal 25, failure_counter.size
  end

  def test_instance_multiple_resource_locking_longer_timeout
    success_counter = Queue.new
    failure_counter = Queue.new

    50.times.map do |i|
      Thread.new do
        success = @client.lock(TEST_KEY, 25, retry_timeout: 2) do
          sleep(0.5)
          success_counter << i
        end

        failure_counter << i unless success
      end
    end.map(&:join)

    assert_equal 50, success_counter.size
    assert_equal 0, failure_counter.size
  end
end

class TestBaseClient < Minitest::Test
  def setup
    @klass = Suo::Client::Base
  end

  def test_not_implemented
    assert_raises(NotImplementedError) do
      @klass.send(:get, TEST_KEY, {})
    end
  end
end

class TestMemcachedClient < Minitest::Test
  include ClientTests

  def setup
    @klass = Suo::Client::Memcached
    @client = @klass.new
    @klass_client = Dalli::Client.new("127.0.0.1:11211")
  end

  def teardown
    @klass_client.delete(TEST_KEY)
  end
end

class TestRedisClient < Minitest::Test
  include ClientTests

  def setup
    @klass = Suo::Client::Redis
    @client = @klass.new
    @klass_client = Redis.new
  end

  def teardown
    @klass_client.del(TEST_KEY)
  end
end

class TestLibrary < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Suo::VERSION
  end
end
