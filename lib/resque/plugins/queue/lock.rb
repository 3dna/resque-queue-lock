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
          _reliably do
            Resque.redis.del( _namespaced_queue_lock(*args) )
          end
        end

        def _acquire_lock(*args)
          _reliably do
            Resque.redis.setnx( _namespaced_queue_lock(*args), Time.now )
          end
        end

        def _namespaced_queue_lock(*args)
          lock_name = queue_lock( *Resque::Job.decode(Resque::Job.encode(args)) )
          "queuelock:#{lock_name}"
        end

        def _reliably
          tries = 0
          begin
            tries += 1
            yield
          rescue Redis::CannotConnectError
            if tries < 30
              sleep tries
              retry
            end
          end
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

