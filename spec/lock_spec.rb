require 'test/unit'
require 'resque'
require 'resque/plugins/queue/lock'

describe Resque::Plugins::Queue::Lock do
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

  before do
    Resque.redis.del 'queue:lock_test'
    Resque.redis.del "queuelock:#{Job.queue_lock}"
    Resque.redis.del "queuelock:#{Job.queue_lock(1)}"
  end

  it "lints as a Resque plugin" do
    Resque::Plugin.lint Resque::Plugins::Queue::Lock
  end

  it "locks the queue" do
    3.times { Resque.enqueue(Job) }

    Resque.redis.llen('queue:lock_test').should == 1
  end

  it "locks the queue with arguments" do
    3.times { Resque.enqueue(Job, 1) }

    Resque.redis.llen('queue:lock_test').should == 1
  end

  it "unlocks the queue when finished" do
    Resque.enqueue(Job)
    Resque.redis.get("queuelock:#{Job.queue_lock}").should be_true
    Resque.dequeue(Job)
    Resque.redis.get("queuelock:#{Job.queue_lock}").should be_nil
  end

  it "unlocks the queue when finished, given arguments" do
    Resque.enqueue(Job, 1)
    Resque.redis.get("queuelock:#{Job.queue_lock(1)}").should be_true
    Resque.dequeue(Job, 1)
    Resque.redis.get("queuelock:#{Job.queue_lock(1)}").should be_nil
  end

  it "unlocks the queue when it starts performing" do
    Resque.enqueue(Job)
    Resque.redis.get("queuelock:#{Job.queue_lock}").should be_true
    job = Resque.reserve(Job.queue)
    job.perform
    Resque.redis.get("queuelock:#{Job.queue_lock}").should be_nil
  end

  it "locks with non-JSON objects" do
    time = Time.now
    Resque.enqueue(Job, time)
    Resque.redis.get("queuelock:#{Job.queue_lock(time.to_s)}").should be_true
    Resque.reserve(Job.queue).perform
    Resque.redis.get("queuelock:#{Job.queue_lock(time.to_s)}").should be_nil
  end

  it "clears the lock when there's an exception" do
    args        = Time.now.to_s
    lock_id     = BrokenJob.queue_lock(args)
    lock_string = "queuelock:#{lock_id}"
    lock        = ->{ Resque.redis.get(lock_string) }

    Resque.enqueue(BrokenJob, args)
    lock.().should be_true

    Resque.reserve(BrokenJob.queue).perform  rescue nil
    lock.().should be_nil
  end

  it "sets the expiration of the key" do
    Resque.enqueue(Job)
    Resque.redis.ttl('queuelock:Job-[]').should == 3600
  end

end
