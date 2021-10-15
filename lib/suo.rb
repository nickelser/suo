require "securerandom"
require "monitor"

begin
  require "dalli"
  require "dalli/cas/client"
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
