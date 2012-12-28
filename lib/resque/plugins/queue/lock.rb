module Resque
  module Plugins
    module Queue
      # If you want only one instance of your job queued at a time,
      # extend it with this module.
      #
      # For example:
      #
      # require 'resque/plugins/queue/lock'
      #
      # class UpdateNetworkGraph
      #   extend Resque::Plugins::Queue::Lock
      #
      #   def self.perform(repo_id)
      #     heavy_lifting
      #   end
      # end
      #
      # No other UpdateNetworkGraph jobs will be placed on the queue,
      # the QueueLock class will check Redis to see if any others are
      # queued with the same arguments before queueing. If another
      # is queued the enqueue will be aborted. The lock will be
      # released when the worker starts performing, so a worker can
      # enqueue another job with identical arguments.
      #
      # If you want to define the key yourself you can override the
      # `queue_lock` class method in your subclass, e.g.
      #
      # class UpdateNetworkGraph
      #   extend Resque::Plugins::Queue::Lock
      #
      #   # Run only one at a time, regardless of repo_id.
      #   def self.queue_lock(repo_id)
      #     "network-graph"
      #   end
      #
      #   def self.perform(repo_id)
      #     heavy_lifting
      #   end
      # end
      module Lock
        # Override in your job to control the lock key. It is
        # passed the same arguments as `perform`, that is, your job's
        # payload.
        def queue_lock(*args)
          "#{name}-#{args.to_s}"
        end

        def namespaced_queue_lock(*args)
          lock_name = queue_lock(*Resque::Job.decode(Resque::Job.encode(args)))
          "queuelock:#{lock_name}"
        end

        def before_enqueue_queue_lock(*args)
          acquire_lock(*args)
        end

        def before_dequeue_queue_lock(*args)
          release_lock(*args)
        end

        def before_perform_queue_lock(*args)
          release_lock(*args)
        end


        def release_lock(*args)
          Resque.redis.del(namespaced_queue_lock(*args))
        end

        def acquire_lock(*args)
          Resque.redis.setnx(namespaced_queue_lock(*args), true)
        end



        def self.all_queue_locks
          Resque.redis.keys('queuelock:*')
        end

        def self.clear_all_queue_locks
          all_queue_locks.map{ |queue_lock| Resque.redis.del(queue_lock) }
        end
      end
    end
  end
end

