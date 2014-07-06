# Fluent::Plugin::Webhook::Github

fluentd input plugin for incoming webhook from GitHub.

(Work in progress. I don't recommend to use this in production)

## Installation

    $ gem install fluent-plugin-webhook-github

## Usage

```
<source>
  type webhook_github
  tag gh

  # optional (values are default)
  bind 0.0.0.0
  port 8080
  mount /
</source>

<match gh.*>
  type stdout
</match>

<match gh.pull_request>
  type hipchat
</match>
```

## Contributing

1. Fork it ( https://github.com/uu59/fluent-plugin-webhook-github/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
