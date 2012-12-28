Gem::Specification.new do |s|
  s.name              = "resque-queue-lock"
  s.version           = "0.0.1"
  s.date              = Time.now.strftime('%Y-%m-%d')
  s.summary           = "A Resque plugin for ensuring only one instance of your job is queued at a time."
  s.homepage          = "http://github.com/mashion/resque-queue-lock"
  s.email             = "admin@mashion.net"
  s.authors           = [ "Chris Wanstrath", "Ray Krueger" ]
  s.has_rdoc          = false

  s.files             = %w( README.md Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("test/**/*")

  s.add_dependency "resque"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 2.12.0"
  s.add_development_dependency "test-unit" # avoids a weird issue: http://bit.ly/PATaLp

  s.description       = <<desc
A Resque plugin. If you want only one instance of your job
queued at a time, extend it with this module.

For example:

    class UpdateNetworkGraph
      extend Resque::Jobs::Queue::Lock

      def self.perform(repo_id)
        heavy_lifting
      end
    end
desc
end
