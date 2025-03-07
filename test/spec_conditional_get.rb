# frozen_string_literal: true

require_relative 'helper'
require 'time'

separate_testing do
  require_relative '../lib/rack/conditional_get'
  require_relative '../lib/rack/lint'
  require_relative '../lib/rack/mock'
end

describe Rack::ConditionalGet do
  def conditional_get(app)
    Rack::Lint.new Rack::ConditionalGet.new(app)
  end

  it "set a 304 status and truncate body when If-Modified-Since hits" do
    timestamp = Time.now.httpdate
    app = conditional_get(lambda { |env|
      [200, { 'last-modified' => timestamp }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => timestamp)

    response.status.must_equal 304
    response.body.must_be :empty?
  end

  it "set a 304 status and truncate body when If-Modified-Since hits and is higher than current time" do
    app = conditional_get(lambda { |env|
      [200, { 'last-modified' => (Time.now - 3600).httpdate }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => Time.now.httpdate)

    response.status.must_equal 304
    response.body.must_be :empty?
  end

  it "set a 304 status and truncate body when If-None-Match hits" do
    app = conditional_get(lambda { |env|
      [200, { 'etag' => '1234' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_NONE_MATCH' => '1234')

    response.status.must_equal 304
    response.body.must_be :empty?
  end

  it "set a 304 status and truncate body when If-None-Match hits but If-Modified-Since is after last-modified" do
    app = conditional_get(lambda { |env|
      [200, { 'last-modified' => (Time.now + 3600).httpdate, 'etag' => '1234', 'content-type' => 'text/plain' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => Time.now.httpdate, 'HTTP_IF_NONE_MATCH' => '1234')

    response.status.must_equal 304
    response.body.must_be :empty?
  end

  it "not set a 304 status if If-Modified-Since hits but etag does not" do
    timestamp = Time.now.httpdate
    app = conditional_get(lambda { |env|
      [200, { 'last-modified' => timestamp, 'etag' => '1234', 'content-type' => 'text/plain' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => timestamp, 'HTTP_IF_NONE_MATCH' => '4321')

    response.status.must_equal 200
    response.body.must_equal 'TEST'
  end

  it "set a 304 status and truncate body when both If-None-Match and If-Modified-Since hits" do
    timestamp = Time.now.httpdate
    app = conditional_get(lambda { |env|
      [200, { 'last-modified' => timestamp, 'etag' => '1234' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => timestamp, 'HTTP_IF_NONE_MATCH' => '1234')

    response.status.must_equal 304
    response.body.must_be :empty?
  end

  it "not affect non-GET/HEAD requests" do
    app = conditional_get(lambda { |env|
      [200, { 'etag' => '1234', 'content-type' => 'text/plain' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      post("/", 'HTTP_IF_NONE_MATCH' => '1234')

    response.status.must_equal 200
    response.body.must_equal 'TEST'
  end

  it "not affect non-200 requests" do
    app = conditional_get(lambda { |env|
      [302, { 'etag' => '1234', 'content-type' => 'text/plain' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_NONE_MATCH' => '1234')

    response.status.must_equal 302
    response.body.must_equal 'TEST'
  end

  it "not affect requests with malformed HTTP_IF_NONE_MATCH" do
    bad_timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S %z')
    app = conditional_get(lambda { |env|
      [200, { 'last-modified' => (Time.now - 3600).httpdate, 'content-type' => 'text/plain' }, ['TEST']] })

    response = Rack::MockRequest.new(app).
      get("/", 'HTTP_IF_MODIFIED_SINCE' => bad_timestamp)

    response.status.must_equal 200
    response.body.must_equal 'TEST'
  end

end
