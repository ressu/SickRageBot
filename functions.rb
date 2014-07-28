require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'google_url_shortener'
require 'json'
require 'openssl'
require 'github_api'
require 'sick_rage_bot/tv'
require_relative 'settings'
require_relative 'db'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
Google::UrlShortener::Base.api_key = $googleapikey



def tv(n, source)
  SickRageBot::Tv.new(n, source)
end

def movie(n)
  search = Nokogiri::XML(open("http://www.imdb.com/find?s=tt&ttype=ft&ref_=fn_ft&q=#{CGI.escape(n.message.split(' ', 2)[1])}"))
  imdbid = search.css('table.findList > tr > td.primary_photo > a')[0]['href'].split('/')[2].split('tt')[1]
  imdburl = "http://www.imdb.com/title/tt#{imdbid}"
  url = Google::UrlShortener::Url.new(:long_url => imdburl)
  movie = Nokogiri::XML(open(imdburl))
  title = movie.css('title').text.split(' -')[0]
  rating = movie.css('div.star-box-giga-star')[0].text
  released = movie.css("meta[itemprop='datePublished']").first['content']
  rottenjson = JSON.load(open("http://api.rottentomatoes.com/api/public/v1.0/movie_alias.json?apikey=#{$rtapikey}&type=imdb&id=#{imdbid}"))

  if rottenjson['error'] == 'Could not find a movie with the specified id'
    rrating = 'No data.'
    dvd = 'No data.'
  else
    rrating = rottenjson['ratings']['audience_score']
    if rottenjson['release_dates']['dvd'].nil?
      dvd = 'No data.'
    else
      dvd = rottenjson['release_dates']['dvd']
    end
  end

  n.reply "#{Format(:bold, 'MOVIE:')} #{title} :: #{Format(:bold, 'Ratings:')} ( IMDB:#{rating}) ( RT: #{rrating} ) :: #{Format(:bold, 'Released:')} Theaters: #{released} - DVD: #{dvd} :: #{Format(:bold, 'URL:')} #{url.shorten!}"
end

def issues(n)
  url = 'https://sickrage.tv/forums/forum'
  enhancements = Nokogiri::XML(open(url)).css('td.topics-count')[1].text
  issues = Nokogiri::XML(open(url)).css('td.topics-count')[5].text

  n.reply "ISSUES - #{issues} issues. :: #{enhancements} feature requests. :: URL: #{Google::UrlShortener::Url.new(:long_url => url).shorten!}"
end

def trakt(u)
  url = "http://api.trakt.tv/user/profile.json/#{$traktapikey}/#{CGI.escape(u.message.split(' ')[1])}"
  json = JSON.load(open(url))

  if json['status'] == 'error' && json['message'] == 'This user has a protected profile.'
    u.reply "TRAKT - #{u.message.split(' ', 2)[1]} is a protected profile."
  else
    username = json['username']
    shows = json['stats']['shows']['watched']
    episodes = json['stats']['episodes']['watched']
    movies = json['stats']['movies']['watched']
    u.reply "TRAKT - #{username} has watched #{movies} movies and #{shows} tv shows consisting of #{episodes} episodes."
  end
  rescue OpenURI::HTTPError => ex
    u.reply "TRAKT - #{u.message.split(' ', 2)[1]} does not exist."
end

def weather(c)
  if c.message.split(' ',2)[1].nil?
    ActiveRecord::Base.connection_pool.with_connection do
      q = Location.where(user: c.user.nick.downcase).last
      @url = "http://api.openweathermap.org/data/2.5/weather?q=#{CGI.escape(q[:location])}&mode=xml&units=metric"
      @json = "http://api.openweathermap.org/data/2.5/weather?q=#{CGI.escape(q[:location])}&units=metric"
    end
  else
    @url = "http://api.openweathermap.org/data/2.5/weather?q=#{CGI.escape(c.message.split(' ',2)[1])}&mode=xml&units=metric"
    @json = "http://api.openweathermap.org/data/2.5/weather?q=#{CGI.escape(c.message.split(' ',2)[1])}&units=metric"
    ActiveRecord::Base.connection_pool.with_connection do
      Location.where(user: c.user.nick.downcase).delete_all
      Location.create(:user => c.user.nick.downcase, :location => c.message.split(' ',2)[1])
    end
  end

  if JSON.load(open(@json))['message'] == 'Error: Not found city'
    c.reply "WEATHER - No results"
  else
    ng = Nokogiri::XML(open(@url))
    city = ng.xpath('//city/@name')
    country = ng.xpath('//city/country').text
    temp = ng.xpath('//temperature/@value')
    max = ng.xpath('//temperature/@max')
    min = ng.xpath('//temperature/@min')
    weather = ng.xpath('//weather/@value')
    c.reply "WEATHER - #{city}, #{country} :: Current #{temp}C, #{weather} :: Max: #{max}C - Min: #{min}C"
  end
end

def mode(u)
  cmd = u.message.split(' ')[0]
  if u.message.split(' ')[1].nil?
    user = u.user.nick
  else
    user = u.message.split(' ')[1]
  end

  case
    when cmd == '!op'
      Channel(u.channel).op(user) if u.channel.opped?(u.user.nick)
    when cmd == '!voice'
      Channel(u.channel).voice(user) if u.channel.opped?(u.user.nick)
    when cmd == '!devoice'
      Channel(u.channel).devoice(user) if u.channel.opped?(u.user.nick)
    when cmd == '!deop'
      Channel(u.channel).deop(user) if u.channel.opped?(u.user.nick)
    when cmd == '!kb'
      if u.channel.opped?(u.user.nick)
        Channel(u.channel).ban("*!*@#{User(u.message.split(' ')[1]).host}")
        Channel(u.channel).kick(u.message.split(' ')[1], 'You have been banned.')
      end
    when cmd == '!ban'
      Channel(u.channel).ban("*!*@#{User(u.message.split(' ')[1]).host}") if u.channel.opped?(u.user.nick)
    when cmd == '!unban'
      Channel(u.channel).unban("*!*@#{User(u.message.split(' ')[1]).host}") if u.channel.opped?(u.user.nick)
    when cmd == '!kick'
      Channel(u.channel).kick(u.message.split(' ')[1], u.message.split(' ', 3)[2]) if u.channel.opped?(u.user.nick)
  end
end

def dblog(u, a)
  ActiveRecord::Base.connection_pool.with_connection do
    if a == 'join'
      Log.create(:chan => u.channel.to_s, :user => u.user.nick.downcase, :message => "joining #{u.channel.to_s}", :time => Time.now.to_s)
    elsif a == 'quit'
      if u.channel.nil?
        Log.create(:chan => 'ALL', :user => u.user.nick.downcase, :message => 'quitting', :time => Time.now.to_s)
      else
        Log.create(:chan => u.channel.to_s, :user => u.user.nick.downcase, :message => "leaving #{u.channel.to_s}", :time => Time.now.to_s)
      end
    elsif a == 'say'
      Log.create(:chan => u.channel.to_s, :user => u.user.nick.downcase, :message => "saying \"#{u.message}\"", :time => Time.now.to_s)
      unless Message.where(who: u.user.nick.downcase).last.nil? or !u.user.authed?
        Message.where(who: u.user.nick.downcase).each do |q|
          User(q[:who]).send "MESSAGE - From: #{q[:from]} :: Message: '#{q[:what]}'"
          User(q[:from]).send "MESSAGE - [SENT] To: #{q[:who]} :: Message: '#{q[:what]} :: '"
          Message.where(who: u.user.nick.downcase).delete_all
        end
      end
    end
  end
end

def time_diff(t)
  cute_date=Array.new
  tables=[ ['day', 24*60*60], ['hour', 60*60], ['minute', 60], ['second', 1] ]

  tables.each do |unit, value|
    o = t.divmod(value)
    p_unit = o[0] > 1 ? (unit + 's') : unit
    cute_date.push("#{o[0]} #{p_unit}") unless o[0] == 0
    t = o[1]
  end
  return cute_date.join(', ')
end

def seen(u, nick)
  ActiveRecord::Base.connection_pool.with_connection do
    q = Log.where(chan: u.channel.to_s, user: nick.downcase).last
    q2 = Log.where(chan: 'ALL', user: nick.downcase).last
    if nick == bot.nick
      u.reply "That's me!"
    elsif nick == u.user.nick
      u.reply "That's you!"
    elsif !q.nil? or !q2.last.nil?
      if q2.nil?
        u.reply "#{nick} was last seen #{q[:message]} #{time_diff((Time.now - Time.parse("#{q[:time]}")))} ago."
      else
        if Time.parse("#{q2[:time]}") > Time.parse("#{q[:time]}")
          u.reply "#{nick} was last seen #{q2[:message]} #{time_diff((Time.now - Time.parse("#{q2[:time]}")))} ago."
        else
          u.reply "#{nick} was last seen #{q[:message]} #{time_diff((Time.now - Time.parse("#{q[:time]}")))} ago."
        end
      end
    else
      u.reply "I haven't seen #{nick}"
    end
  end
end

def list(u)
  if u.message.split(" ",3)[1] == 'add' and u.user.nick == $admin
    ActiveRecord::Base.connection_pool.with_connection do
      Command.create(:command => u.message.split(" ",3)[2])
    end
  else
    ActiveRecord::Base.connection_pool.with_connection do
      Command.all.each do |x|
        User(u.user.nick).send(x[:command])
      end
    end
  end
end

def tell(u)
  ActiveRecord::Base.connection_pool.with_connection do
    who = u.message.split(' ',3)[1].downcase
    what = u.message.split(' ',3)[2]
    from = u.user.nick
    unless who.nil? or what.nil? or from.nil?
      Message.create(:who => who, :what => what, :from => from, :time => Time.now.to_s)
      u.reply 'Will do!'
    end
  end
end

def latest(b)
  dev = Github::Repos.new.branch('echel0n','SickRage','dev')['commit']['commit']
  master = Github::Repos.new.branch('echel0n','SickRage','master')['commit']['commit']
  nightly = Github::Repos.new.branch('echel0n','SickRage','nightly')['commit']['commit']
  if b.message.split(' ',2)[1].nil?
    dname = dev['author']['name']
    dcommit = dev['url'].split("/")[8][0..7]
    dmsg = dev['message'].gsub("\n\n"," ")
    durl = Google::UrlShortener::Url.new(:long_url => "https://github.com/echel0n/SickRage/commit/#{dev['url'].split("/")[8]}").shorten!
    dbranch = 'dev'
    name = master['author']['name']
    commit = master['url'].split("/")[8][0..7]
    msg = master['message'].gsub("\n\n"," ")
    url = Google::UrlShortener::Url.new(:long_url => "https://github.com/echel0n/SickRage/commit/#{master['url'].split("/")[8]}").shorten!
    branch = 'master'
    nname = nightly['author']['name']
    ncommit = nightly['url'].split("/")[8][0..7]
    nmsg = nightly['message'].gsub("\n\n"," ")
    nurl = Google::UrlShortener::Url.new(:long_url => "https://github.com/echel0n/SickRage/commit/#{nightly['url'].split("/")[8]}").shorten!
    nbranch = 'nightly'
    b.reply "The latest commit in #{branch}: #{name}, #{commit}, #{msg}, #{url}"
    b.reply "The latest commit in #{dbranch}: #{dname}, #{dcommit}, #{dmsg}, #{durl}"
    b.reply "The latest commit in #{nbranch}: #{nname}, #{ncommit}, #{nmsg}, #{nurl}"
  elsif b.message.split(' ',2)[1].downcase == 'dev'
    name = dev['author']['name']
    commit = dev['url'].split("/")[8][0..7]
    msg = dev['message'].gsub("\n\n"," ")
    url = Google::UrlShortener::Url.new(:long_url => "https://github.com/echel0n/SickRage/commit/#{dev['url'].split("/")[8]}").shorten!
    branch = 'dev'

    b.reply "The latest commit in #{branch}: #{name}, #{commit}, #{msg}, #{url}"
  elsif b.message.split(' ',2)[1].downcase == 'master'
    name = master['author']['name']
    commit = master['url'].split("/")[8][0..7]
    msg = master['message'].gsub("\n\n"," ")
    url = Google::UrlShortener::Url.new(:long_url => "https://github.com/echel0n/SickRage/commit/#{master['url'].split("/")[8]}").shorten!
    branch = 'master'

    b.reply "The latest commit in #{branch}: #{name}, #{commit}, #{msg}, #{url}"
  elsif b.message.split(' ',2)[1].downcase == 'nightly'
    name = nightly['author']['name']
    commit = nightly['url'].split("/")[8][0..7]
    msg = nightly['message'].gsub("\n\n"," ")
    url = Google::UrlShortener::Url.new(:long_url => "https://github.com/echel0n/SickRage/commit/#{nightly['url'].split("/")[8]}").shorten!
    branch = 'nightly'

    b.reply "The latest commit in #{branch}: #{name}, #{commit}, #{msg}, #{url}"
  end
end

def ut(m, uptime)
  m.reply "Uptime: #{time_diff(Time.now - uptime)}"
end
