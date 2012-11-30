require 'test/unit'
require 'resque'
require 'resque/plugins/queue/lock'

class LockTest < Test::Unit::TestCase
  class Job
    extend Resque::Plugins::Queue::Lock
    def self.queue; :lock_test end

    def self.perform
      raise "Woah woah woah, that wasn't supposed to happen"
    end
  end
  class ShortTimeoutJob < Job
    def self.queue_lock_timeout(*args)
      1
    end
  end

  def setup
    Resque.redis.del('queue:lock_test')
    Resque.redis.del("queuelock:#{Job.lock}")
    Resque.redis.del("queuelock:#{Job.lock(1)}")
  end

  def test_lint
    assert_nothing_raised do
      Resque::Plugin.lint(Resque::Plugins::Queue::Lock)
    end
  end

  def test_version
    major, minor, patch = Resque::Version.split('.')
    assert_equal 1, major.to_i
    assert minor.to_i >= 17
    assert Resque::Plugin.respond_to?(:before_enqueue_hooks)
  end

  def test_lock
    3.times { Resque.enqueue(Job) }

    assert_equal 1, Resque.redis.llen('queue:lock_test')
  end

  def test_lock_with_args
    3.times { Resque.enqueue(Job, 1) }

    assert_equal 1, Resque.redis.llen('queue:lock_test')
  end

  def test_unlock
    Resque.enqueue(Job)
    assert_equal "true", Resque.redis.get("queuelock:#{Job.lock}")
    Resque.dequeue(Job)
    assert_nil Resque.redis.get("queuelock:#{Job.lock}")
  end
  def test_unlock_with_args
    Resque.enqueue(Job, 1)
    assert_equal "true", Resque.redis.get("queuelock:#{Job.lock(1)}")
    Resque.dequeue(Job, 1)
    assert_nil Resque.redis.get("queuelock:#{Job.lock(1)}")
  end
  def test_lock_timeout_default_present
    assert_not_nil Job.queue_lock_timeout
  end

  def test_custom_lock_timeout
    Resque.enqueue(ShortTimeoutJob)
    assert_equal "true", Resque.redis.get("queuelock:#{ShortTimeoutJob.lock}")
    sleep ShortTimeoutJob.queue_lock_timeout
    assert_nil Resque.redis.get("queuelock:#{ShortTimeoutJob.lock}")
  end
end
