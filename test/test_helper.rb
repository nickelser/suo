$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

if ENV["CODECLIMATE_REPO_TOKEN"]
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
end

require "suo"
require "thread"
require "minitest/autorun"
require "minitest/benchmark"

ENV["SUO_TEST"] = "true"
