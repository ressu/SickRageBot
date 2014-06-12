require 'cinch'
require 'cinch/plugins/identify'
require_relative 'functions'
require_relative 'settings'
require_relative 'github_commits'
require_relative 'db'

cinch = Cinch::Bot.new do
  configure do |config|
    config.server = $server
    config.channels = $channel
    config.nick = $nick
    config.realname = 'SickRage'
    config.user = 'SickRage'
    config.plugins.plugins = [Cinch::Plugins::Identify, Cinch::HttpServer, Cinch::GithubCommits]
    config.plugins.options[Cinch::HttpServer] = {
     :host => '0.0.0.0',
     :port => 1234
    }
    config.plugins.options[Cinch::Plugins::Identify] = {
        :password => $nspass,
        :type     => :nickserv,
    }
  end

  on :message, /^!tvdb (.+)/i do |m|
    tv(m, 'tvdb')
  end

  on :message, /^!tvrage (.+)/i do |m|
    tv(m, 'tvrage')
  end

  on :message, /^!tv (.+)/i do |m|
    tv(m, 'tvdb')
    tv(m, 'tvrage')
  end

  on :message, /^!issues/i do |m|
    issues(m)
  end

  on :message, /^!list/i do |m|
    list(m)
  end

  on :message, /^!movie/i do |m|
    movie(m)
  end

  on :message, /^!trakt/i do |m|
    trakt(m)
  end

  on :message, /^!access/i do |m|
    access(m)
  end

  on :message, /(.+)ACTION slaps #{$nick}/i do |m|
    m.action_reply "slaps #{m.user.nick} around a bit with a large trout"
  end

  on :message, /^!op|^!voice|^!deop|^!devoice|^!kb|^!ban|^!unban|^!kick/i do |m|
    mode(m)
  end

  on :join do |m|
    dblog(m,'join')
  end

  on :leaving do |m|
    dblog(m,'quit')
  end

  on :channel do |m|
    dblog(m,'say')
  end

  on :message, /^!seen (.+)/i do |m, nick|
    seen(m, nick)
  end

  on :message, /^!weather/i do |m|
    weather(m)
  end

  on :message, /^!tell (.+)/i do |m|
    tell(m)
  end

  on :message, /^!quit/i do |m|
    if m.user.nick == $admin and m.user.authed?
      cinch.quit(m.message.split(" ",2)[1])
    end
  end
end

cinch.start