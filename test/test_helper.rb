$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "suo"
require "thread"
require "minitest/autorun"
require "minitest/benchmark"

ENV["SUO_TEST"] = "true"

