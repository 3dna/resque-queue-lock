Resque Queue Lock
=================

A [Resque][rq] plugin. Requires Resque 1.7.0.

If you want only one instance of your job queued at a time, extend it with this module.

For example:

    require 'resque/plugins/queue/lock'

    class ExampleJob
      extend Resque::Plugins::Queue::Lock

      def self.perform(*args)
        heavy_lifting
      end
    end

While this job is queued, no other ExampleJob jobs with the same arguments will be placed on the queue.

If you want to define the lock id yourself you can override the `queue_lock` class method in your job class. It takes the same arguments as `perform`. e.g.

    class ExampleJob
      extend Resque::Plugins::Queue::Lock

      def self.queue_lock(*args)
        "network-graph"
      end

      def self.perform(*args)
        heavy_lifting
      end
    end

This differs from the [Resque Lock plugin][resque-lock] in that this plugin will allow jobs with the same lock key to be running and in the queue at the same time. It only prevents multiple jobs with the same lock from being in the queue.

[rq]: http://github.com/defunkt/resque
[resque-lock]: https://github.com/defunkt/resque-lock
