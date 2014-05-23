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
    User(m.user.nick).send('!tvdb <name of show>: Searches TVDB for specified show. Eg. !tvdb the simpsons')
    User(m.user.nick).send('!tvrage <name of show>: Searches TVRAGE for specified show. Eg. !tvrage the simpsons')
    User(m.user.nick).send('!tv <name of show>: Searches both TVDB and TVRAGE for specified show. Eg. !tv the simpsons')
    User(m.user.nick).send('!movie <name of movie>: Searches IMDB and RT for a specified movie. Eg. !movie spiderman')
    User(m.user.nick).send('!issues: Reports amount of open issues and unverified bugs.')
    User(m.user.nick).send('!trakt <user>: Returns watched stats for the inputted user. Eg. !trakt senseye')
  end

  on :message, /^!movie/i do |m|
    movie(m)
  end

  on :message, /^!trakt/i do |m|
    trakt(m)
  end

  on :message, /(.+)ACTION slaps #{$nick}/i do |m|
    m.action_reply "slaps #{m.user.nick} around a bit with a large trout"
  end

  on :message, /^!op|^!voice|^!deop|^!devoice|^!kb|^!ban|^!unban|^!kick/i do |m|
    mode(m)
  end

  on :join do |m|
    autoop(m)
  end

  on :channel do |m|
    Log.create(:chan => m.channel.to_s, :user => m.user.nick.downcase, :message => m.message, :time => Time.now.to_s)
  end

  on :message, /^!seen (.+)/ do |m, nick|
    if nick == bot.nick
      m.reply "That's me!"
    elsif nick == m.user.nick
      m.reply "That's you!"
    elsif !Log.where(chan: m.channel.to_s, user: m.message.split(' ')[1]).last.nil?
      q = Log.where(chan: m.channel.to_s, user: m.message.split(' ')[1]).last
      m.reply "#{q[:user]} was last seen saying \"#{q[:message]}\" #{(Time.now - Time.parse("#{q[:time]}")).duration} ago."
    else
      m.reply "I haven't seen #{nick}"
    end
  end
end

cinch.start