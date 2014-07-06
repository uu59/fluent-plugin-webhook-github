# -- coding: utf-8

require "thread"
require "json"
require 'fluent/process'

module Fluent
  class WebhookGithubInput < Input
    include DetachProcessMixin

    Plugin.register_input('webhook_github', self)

    config_param :tag, :string
    config_param :bind, :string, :default => "0.0.0.0"
    config_param :port, :integer, :default => 8080
    config_param :mount, :string, :default => "/"

    def start
      @thread = Thread.new(&method(:run))
    end

    def shutdown
      Thread.kill(@thread)
    end

    def run
      server = WEBrick::HTTPServer.new(
        :BindAddress => @bind,
        :Port => @port,
      )
      $log.debug "Listen on http://#{@bind}:#{@port}#{@mount}"
      server.mount_proc(@mount) do |req, res|
        begin
          $log.debug req.header
          payload = JSON.parse(req.body || "{}")
          event = req.header["x-github-event"].first
          process(event, payload)
          res.status = 204
        rescue => e
          $log.error e.inspect
          $log.error e.backtrace.join("\n")
          res.status = 400
        end
      end
      server.start
    end

    def process(event, payload)
      content = case event
      when "issue", "issue_comment"
        {
          :url => payload["issue"]["html_url"],
          :title => payload["issue"]["title"],
          :user => payload["issue"]["user"]["login"],
          :body => payload["comment"]["body"],
        }
      when "pull_request"
        {
          :url => payload["pull_request"]["html_url"],
          :title => payload["pull_request"]["title"],
          :user => payload["pull_request"]["user"]["login"],
          :body => payload["pull_request"]["body"],
        }
      when "pull_request_review_comment"
        {
          :url => payload["comment"]["html_url"],
          :title => payload["pull_request"]["title"],
          :user => payload["comment"]["user"]["login"],
          :body => payload["comment"]["body"],
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
