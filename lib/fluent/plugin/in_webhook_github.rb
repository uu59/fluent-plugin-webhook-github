# -- coding: utf-8

require "thread"
require "json"
require 'fluent/process'
require 'openssl'
require 'secure_compare'

module Fluent
  class WebhookGithubInput < Input
    include DetachProcessMixin

    Plugin.register_input('webhook_github', self)

    config_param :tag, :string
    config_param :bind, :string, :default => "0.0.0.0"
    config_param :port, :integer, :default => 8080
    config_param :mount, :string, :default => "/"
    config_param :secret, :string, :default => nil

    def start
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      @server.shutdown
      Thread.kill(@thread)
    end

    HMAC_DIGEST = OpenSSL::Digest.new('sha1')

    def run
      @server = WEBrick::HTTPServer.new(
        :BindAddress => @bind,
        :Port => @port,
      )
      $log.debug "Listen on http://#{@bind}:#{@port}#{@mount}"
      @server.mount_proc(@mount) do |req, res|
        begin
          $log.debug req.header

          if verify_signature(req)
            payload = JSON.parse(req.body || "{}")
            event = req.header["x-github-event"].first
            process(event, payload)
            res.status = 204
          else
            res.status = 401
          end
        rescue => e
          $log.error e.inspect
          $log.error e.backtrace.join("\n")
          res.status = 400
        end
      end
      @server.start
    end

    def verify_signature(req)
      return true unless @secret
      sig = 'sha1='+OpenSSL::HMAC.hexdigest(HMAC_DIGEST, @secret, req.body)
      SecureCompare.compare(sig, req.header["x-hub-signature"].first)
    end

    def process(event, payload)
      content = case event
      when "issue", "issue_comment"
        {
          :url   => payload["issue"] && payload["issue"]["html_url"],
          :title => payload["issue"] && payload["issue"]["title"],
          :user  => payload["issue"] && payload["issue"]["user"]["login"],
          :body  => payload["comment"] && payload["comment"]["body"],
        }
      when "pull_request"
        {
          :url   => payload["pull_request"] && payload["pull_request"]["html_url"],
          :title => payload["pull_request"] && payload["pull_request"]["title"],
          :user  => payload["pull_request"] && payload["pull_request"]["user"]["login"],
          :body  => payload["pull_request"] && payload["pull_request"]["body"],
        }
      when "pull_request_review_comment"
        {
          :url   => payload["comment"] && payload["comment"]["html_url"],
          :title => payload["pull_request"] && payload["pull_request"]["title"],
          :user  => payload["comment"] && payload["comment"]["user"]["login"],
          :body  => payload["comment"] && payload["comment"]["body"],
        }
      end
      if content
        content[:origin] = "github"
        $log.info "tag: #{@tag.dup}.#{event}, event:#{event}, content:#{content}"
        Engine.emit("#{@tag.dup}.#{event}", Engine.now, content) if content
      else
        $log.warn "unknown hook received #{event} #{payload.inspect}"
      end
    end
  end
end
