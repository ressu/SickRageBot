require 'cinch'
require_relative 'functions'
require_relative 'settings'
require_relative 'github_commits'

cinch = Cinch::Bot.new do
  configure do |config|
    config.server = $server
    config.channels = [$channel]
    config.nick = $nick
    config.realname = 'SickRage'
    config.user = 'SickRage'
    config.plugins.plugins = [Cinch::HttpServer, Cinch::GithubCommits]
    config.plugins.options[Cinch::HttpServer] = {
     :host => '0.0.0.0',
     :port => 1234
   }
  end

  on :message, /^!tvdb (.+)/i do |m|
    if m.channel == $channel
      tv(m, 'tvdb')
    end
  end

  on :message, /^!tvrage (.+)/i do |m|
    if m.channel == $channel
      tv(m, 'tvrage')
    end
  end

  on :message, /^!tv (.+)/i do |m|
    if m.channel == $channel
      tv(m, 'tvdb')
      tv(m, 'tvrage')
    end
  end

  on :message, /^!issues/i do |m|
    if m.channel == $channel
      issues
    end
  end

  on :message, /^!list/i do |m|
    User(m.user.nick).send('!tvdb <name of show>: Searches TVDB for specified show. Eg. !tvdb the simpsons')
    User(m.user.nick).send('!tvrage <name of show>: Searches TVRAGE for specified show. Eg. !tvrage the simpsons')
    User(m.user.nick).send('!tv <name of show>: Searches both TVDB and TVRAGE for specified show. Eg. !tv the simpsons')
    User(m.user.nick).send('!movie <name of movie>: Searches IMDB and RT for a specified movie. Eg. !movie spiderman')
    User(m.user.nick).send('!issues: Reports amount of open issues and unverified bugs.')
  end

  on :message, /^!movie/i do |m|
    if m.channel == $channel
      movie(m)
    end
  end
end

cinch.start