require "securerandom"
require "monitor"

begin
  require "dalli"

  if Gem::Version.new(Dalli::VERSION) < Gem::Version.new('3.0.0')
    require "dalli/cas/client"
  end
rescue LoadError
end

begin
  require "redis"
rescue LoadError
end

require "msgpack"

require "suo/version"

require "suo/errors"
require "suo/client/base"
require "suo/client/memcached"
require "suo/client/redis"
