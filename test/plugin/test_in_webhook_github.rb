require 'helper'
require 'net/http'

class GithubWebhookInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  PORT = unused_port
  CONFIG = %[
    port #{PORT}
    tag gwebhook
  ]

  def create_driver(conf=CONFIG, tag='test')
    Fluent::Test::OutputTestDriver.new(Fluent::WebhookGithubInput, tag).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) {
      d = create_driver('')
    }
    d = create_driver
    assert_equal 'gwebhook', d.instance.tag
    assert_equal PORT, d.instance.port
    assert_equal '/', d.instance.mount
    assert_equal '0.0.0.0', d.instance.bind
  end

  def test_basic
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    Fluent::Engine.now = time

    d.expect_emit "gwebhook.issue", time, {
      :event  => 'issue',
      :url    => 'http://',
      :title  => 'tttt',
      :user   => 'Ore',
      :body   => 'Karada',
      :origin => 'github',
    }

    payload = {
      'issue' => {
        'html_url' => 'http://',
        'title'    => 'tttt',
        'user'     => {
          'login' => 'Ore',
        },
      },
      'comment' => {
        'body' => 'Karada',
      }
    }

    d.run do
      d.expected_emits.each {|tag, time, record|
        res = post("/", payload.to_json, {
          'x-github-event' => 'issue',
        })
        assert_equal "204", res.code
      }
    end
  end


  def test_signature
    d = create_driver(CONFIG + %[
      secret secret1234
    ])

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    Fluent::Engine.now = time

    d.expect_emit "gwebhook.issue", time, {
      :event  => 'issue',
      :url    => nil,
      :title  => nil,
      :user   => nil,
      :body   => nil,
      :origin => 'github',
    }

    d.run do
      d.expected_emits.each {|tag, time, record|
        res = post("/", '{"hoge":"fuga"}', {
          'x-github-event'  => 'issue',
          'x-hub-signature' => 'sha1=5ea783ea13c9feef6dbb9c8c805450e2ba1fb0c0',
        })
        assert_equal "204", res.code
      }
      res = post("/", '{"hoge":"fuga"}', {
        'x-github-event'  => 'issue',
        'x-hub-signature' => 'sha1=5ea783ea13c9feef6dbb9c8c805450e2ba1fb0c0-dummy',
      })
      assert_equal "401", res.code
    end
  end

  def test_with_payload
    d = create_driver(CONFIG + %[
      with_payload true
    ])

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    Fluent::Engine.now = time

    payload = {
      'issue' => {
        'html_url' => 'http://',
        'title'    => 'tttt',
        'user'     => {
          'login' => 'Ore',
        },
      },
      'comment' => {
        'body' => 'Karada',
      }
    }

    d.expect_emit "gwebhook.issue", time, {
      :event   => 'issue',
      :url     => 'http://',
      :title   => 'tttt',
      :user    => 'Ore',
      :body    => 'Karada',
      :origin  => 'github',
      :payload => payload
    }

    payload_delete = {
      'ref'         => 'simple-tag',
      'ref_type'    => 'tag',
      'pusher_type' => 'user',
      'repository'  => {},
      'sender'      => {
        'login' => 'baxterthehacker',
        'id'    => 6752317,
      },
    }

    d.expect_emit "gwebhook.delete", time, {
      :event   => 'delete',
      :origin  => 'github',
      :payload => payload_delete,
    }

    d.run do
      d.expected_emits.each {|tag, time, record|
        res = post("/", record[:payload].to_json, {
          'x-github-event' => record[:event],
        })
        assert_equal "204", res.code
      }
    end
  end


  def post(path, params, header = {})
    http = Net::HTTP.new("127.0.0.1", PORT)
    req = Net::HTTP::Post.new(path, header)
    if params.is_a?(String)
      req.body = params
    else
      req.set_form_data(params)
    end
    http.request(req)
  end

end
