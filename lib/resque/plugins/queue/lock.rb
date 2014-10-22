module Resque
  module Plugins
    module Queue
      module Lock
        # Override in your job to control the lock key. It is
        # passed the same arguments as `perform`, that is, your job's
        # payload.
        def queue_lock(*args)
          "#{name}-#{args.to_s}"
        end

        # Override in your job to control the worker lock experiation time. This
        # is the time in seconds that the lock should be considered valid. The
        # default is one hour (3600 seconds).
        def queue_lock_timeout
          3600
        end

        def before_enqueue__queue_lock(*args)
          _acquire_lock(*args)
        end

        def before_dequeue__queue_lock(*args)
          _release_lock(*args)
        end

        def before_perform__queue_lock(*args)
          _release_lock(*args)
        end

        def _release_lock(*args)
          Resque.redis.del( _namespaced_queue_lock(*args) )
        end

        def _acquire_lock(*args)
          if Resque.redis.setnx( _namespaced_queue_lock(*args), true )
            Resque.redis.expire( _namespaced_queue_lock(*args), queue_lock_timeout )
          else
            false
          end
        end

        def _namespaced_queue_lock(*args)
          lock_name = queue_lock( *Resque::Job.decode(Resque::Job.encode(args)) )
          "queuelock:#{lock_name}"
        end

        def self.all_queue_locks
          Resque.redis.keys('queuelock:*')
        end

        def self.clear_all_queue_locks
          all_queue_locks.each{ |queue_lock| Resque.redis.del(queue_lock) }
        end
      end
    end
  end
end

