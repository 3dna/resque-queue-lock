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
      # `lock` class method in your subclass, e.g.
      #
      # class UpdateNetworkGraph
      #   extend Resque::Plugins::Queue::Lock
      #
      #   # Run only one at a time, regardless of repo_id.
      #   def self.lock(repo_id)
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
        def lock(*args)
          "#{name}-#{args.to_s}"
        end

        # Override in your job to control the queue lock experiation time. This
        # is the time in seconds that the lock should be considered valid. The
        # default is one hour (3600 seconds).
        def queue_lock_timeout(*)
          3600
        end

        def namespaced_lock(*args)
          "queuelock:#{lock(*args)}"
        end

        def before_enqueue_lock(*args)
          acquire_queue_lock(*args) && set_queue_lock_expiration(*args)
        end

        def before_dequeue_lock(*args)
          Resque.redis.del(namespaced_lock(*args))
        end

        def before_perform_lock(*args)
          before_dequeue_lock(*args)
        end

        def self.all_locks
          Resque.redis.keys('queuelock:*')
        end
        def self.clear_all_locks
          all_locks.collect { |x| Resque.redis.del(x) }.count
        end

        private
        def acquire_queue_lock(*args)
          Resque.redis.setnx(namespaced_lock(*args), true)
        end

        def set_queue_lock_expiration(*args)
          Resque.redis.expire(namespaced_lock(*args), queue_lock_timeout(*args))
        end
      end
    end
  end
end

