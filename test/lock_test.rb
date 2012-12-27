require 'test/unit'
require 'resque'
require 'resque/plugins/queue/lock'

class LockTest < Test::Unit::TestCase
  class Job
    extend Resque::Plugins::Queue::Lock
    def self.queue; :lock_test end

    def self.perform(*)
    end
  end

  class BrokenJob
    extend Resque::Plugins::Queue::Lock
    def self.queue; :lock_test_broken end

    def self.perform(*)
      raise "ERROR"
    end
  end

  def setup
    Resque.redis.del('queue:lock_test')
    Resque.redis.del("queuelock:#{Job.queue_lock}")
    Resque.redis.del("queuelock:#{Job.queue_lock(1)}")
  end

  def test_lint
    assert_nothing_raised do
      Resque::Plugin.lint(Resque::Plugins::Queue::Lock)
    end
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
    assert_equal "true", Resque.redis.get("queuelock:#{Job.queue_lock}")
    Resque.dequeue(Job)
    assert_nil Resque.redis.get("queuelock:#{Job.queue_lock}")
  end

  def test_unlock_with_args
    Resque.enqueue(Job, 1)
    assert_equal "true", Resque.redis.get("queuelock:#{Job.queue_lock(1)}")
    Resque.dequeue(Job, 1)
    assert_nil Resque.redis.get("queuelock:#{Job.queue_lock(1)}")
  end

  def test_unlock_on_perform
    Resque.enqueue(Job)
    assert_equal "true", Resque.redis.get("queuelock:#{Job.queue_lock}")
    job = Resque.reserve(Job.queue)
    job.perform
    assert_nil Resque.redis.get("queuelock:#{Job.queue_lock}")
  end

  def test_lock_with_non_json_objects
    time = Time.now
    Resque.enqueue(Job, time)
    assert_equal "true", Resque.redis.get("queuelock:#{Job.queue_lock(time.to_s)}")
    Resque.reserve(Job.queue).perform
    assert_nil Resque.redis.get("queuelock:#{Job.queue_lock(time.to_s)}")
  end

  def test_lock_cleared_on_exception
    args        = Time.now.to_s
    lock_id     = BrokenJob.queue_lock(args)
    lock_string = "queuelock:#{lock_id}"
    lock        = ->{ Resque.redis.get(lock_string) }

    Resque.enqueue(BrokenJob, args)
    assert_equal "true", lock.()

    Resque.reserve(BrokenJob.queue).perform  rescue nil
    assert_nil lock.()
  end
end
