require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'google_url_shortener'
require 'json'
require 'openssl'
require_relative 'settings'
require_relative 'db'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
Google::UrlShortener::Base.api_key = $googleapikey

def nexta(xml, source)
  if source == 'tvrage'
    s = { :aired => 'Season > episode > airdate',
          :day => 'airday',
          :time => 'airtime' }
  else
    s = { :aired => 'Episode > FirstAired',
          :day => 'Airs_DayOfWeek',
          :time => 'Airs_Time' }
  end
  xml.search(':empty').remove
  split = xml.css(s[:aired]).last.text.split('-')
  if Date.valid_date?(split[0].to_i, split[1].to_i, split[2].to_i) == true and Date.parse(xml.css(s[:aired]).last.text) < Date.today
    return 'No data.'
  end
  xml.css(s[:aired]).each do |x|
    var = x.text.split('-')
    if Date.valid_date?(var[0].to_i, var[1].to_i, var[2].to_i) == true and Date.parse(x.text) >= Date.today
      if (Date.parse(x.text) - Date.today).to_i == 1
        return "#{x.text} #{xml.css(s[:day]).text} #{xml.css(s[:time]).text} (#{(Date.parse(x.text) - Date.today).to_i} day left)"
      elsif (Date.parse(x.text) - Date.today).to_i == 0
        return "#{x.text} #{xml.css(s[:day]).text} #{xml.css(s[:time]).text} (Today)"
      else
        return "#{x.text} #{xml.css(s[:day]).text} #{xml.css(s[:time]).text} (#{(Date.parse(x.text) - Date.today).to_i} days left)"
      end
    end
  end
end


def tv(n, source)
  if source == 'tvrage'
    s = { :id => 'showid',
          :name => 'name',
          :status => 'status',
          :searchurl => 'http://services.tvrage.com/feeds/search.php?show=',
          :tvurl => 'http://services.tvrage.com/feeds/full_show_info.php?sid=',
          :link => 'Show > showlink' }
  else
    s = { :id => 'seriesid',
          :name => 'SeriesName',
          :status => 'Status',
          :searchurl => 'http://thetvdb.com/api/GetSeries.php?seriesname=',
          :tvurl => "http://thetvdb.com/api/#{$tvdbapikey}/series/",
          :tvurl2 => '/all/en.xml' }
  end
  search = Nokogiri::XML(open("#{s[:searchurl]}#{CGI.escape(n.message.split(' ', 2)[1])}"))
  unless search.css(s[:id]).first.nil?
    show = Nokogiri::XML(open("#{s[:tvurl]}#{search.css(s[:id]).first.text}#{s[:tvurl2]}"))
    tvname = show.css(s[:name]).text
    tvstatus = show.css(s[:status]).text

    if s[:link].nil?
      url = Google::UrlShortener::Url.new(:long_url => "http://thetvdb.com/?tab=series&id=#{search.css(s[:id]).first.text}")
    else
      url = Google::UrlShortener::Url.new(:long_url => (show.css(s[:link]).text))
    end

    if tvstatus == 'Ended' or tvstatus == 'Canceled/Ended'
      n.reply "#{Format(:bold, "#{source.upcase} - Show:")} #{tvname} :: #{Format(:bold, 'Status:')} #{tvstatus} :: URL: #{url.shorten!}"
    else
      n.reply "#{Format(:bold, "#{source.upcase} - Show:")} #{tvname} :: #{Format(:bold, 'Status:')} #{tvstatus} :: #{Format(:bold, 'Next:')} #{nexta(show, source)} :: URL: #{url.shorten!}"
    end
  end
  if search.css(s[:id]).first.nil?
    n.reply "#{Format(:bold, source.upcase)} - No results found."
  end
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

def mode(u)
  ActiveRecord::Base.connection_pool.with_connection do
    cmd = u.message.split(' ')[0]
    user = u.message.split(' ')[1]
    q = Access.where(user: u.user.nick, chan: u.channel.to_s).last

    case
      when cmd == '!op'
        if user.nil?
          Channel(u.channel).op(u.user.nick) if u.user.authed? and q[:roles].include?('o')
        else
          Channel(u.channel).op(user) if u.user.authed? and q[:roles].include?('o')
        end
      when cmd == '!voice'
        if user.nil?
          Channel(u.channel).voice(u.user.nick) if u.user.authed? and q[:roles].include?('v')
        else
          Channel(u.channel).voice(user) if u.user.authed? and q[:roles].include?('v')
        end
      when cmd == '!devoice'
        if user.nil?
          Channel(u.channel).devoice(u.user.nick) if u.user.authed? and q[:roles].include?('v')
        else
          Channel(u.channel).devoice(user) if u.user.authed? and q[:roles].include?('v')
        end
      when cmd == '!deop'
        if user.nil?
          Channel(u.channel).deop(u.user.nick) if u.user.authed? and q[:roles].include?('o')
        else
          Channel(u.channel).deop(user) if u.user.authed? and q[:roles].include?('o')
        end
      when cmd == '!kb'
        if u.user.authed? and q[:roles].include?('kb')
          Channel(u.channel).ban("*!*@#{User(user).host}")
          Channel(u.channel).kick(user, 'You have been banned.')
        end
      when cmd == '!ban'
        Channel(u.channel).ban("*!*@#{User(user).host}") if u.user.authed? and q[:roles].include?('b')
      when cmd == '!unban'
        Channel(u.channel).unban("*!*@#{User(user).host}") if u.user.authed? and q[:roles].include?('b')
      when cmd == '!kick'
        Channel(u.channel).kick(user, u.message.split(' ')[2]) if u.user.authed? and q[:roles].include?('k')
    end
  end
end

def autoop(u)
  ActiveRecord::Base.connection_pool.with_connection do
    unless u.user.nick == $nick
      q = Access.where(user: u.user.nick, chan: u.channel.to_s).last

      if u.user.authed? and q[:roles].include?('o')
        Channel(u.channel).op(u.user.nick)
      elsif u.user.authed? and q[:roles].include?('v')
        Channel(u.channel).voice(u.user.nick)
      end
    end
  end
end

class Numeric
  def duration
    secs  = self.to_int
    mins  = secs / 60
    hours = mins / 60
    days  = hours / 24

    if days > 0
      hour_remainder = hours % 24
      if hour_remainder > 0
        hour_str = hour_remainder == 1 ? 'hour' : 'hours'
        "#{days} days and #{hour_remainder} #{hour_str}"
      elsif days == 1
        "#{days} day"
      else
        "#{days} days"
      end
    elsif hours > 0
      min_remainder = mins % 60
      if min_remainder > 0
        min_str = min_remainder == 1 ? 'minute' : 'minutes'
        "#{hours} hours and #{min_remainder} #{min_str}"
      elsif hours == 1
        "#{hours} hour"
      else
        "#{hours} hours"
      end
    elsif mins > 0
      sec_remainder = secs % 60
      if sec_remainder > 0
        sec_str = sec_remainder == 1 ? 'second' : 'seconds'
        "#{mins} minutes and #{sec_remainder} #{sec_str}"
      elsif minutes == 1
        "#{mins} minute"
      else
        "#{mins} minutes"
      end
    elsif secs == 1
      "#{secs} second"
    elsif secs >= 0
      "#{secs} seconds"
    end
  end
end

def access(u)
  ActiveRecord::Base.connection_pool.with_connection do
    if u.user.authed? and u.user.nick == $admin
      chan = u.message.split(' ')[1]
      cmd = u.message.split(' ')[2]
      user = u.message.split(' ')[3]
      role = u.message.split(' ')[4]

      if cmd == 'add'
        Access.create(:chan => chan, :user => user, :roles => role)
        u.reply "Added #{user} as \"#{role}\" in #{chan}"
      elsif cmd == 'del'
        Access.where(user: user, chan: chan).destroy_all
        u.reply "Removed #{user} from #{chan}"
      elsif cmd == 'list'
        Access.where(chan: chan).each do |q|
          u.reply "#{q[:user]} :: Roles: #{q[:roles]}"
        end
      end
    end
  end
end

def dblog(u, a)
  ActiveRecord::Base.connection_pool.with_connection do
    if a == 'join'
      Log.create(:chan => u.channel.to_s, :user => u.user.nick.downcase, :message => "joining #{u.channel.to_s}", :time => Time.now.to_s)
    elsif a == 'quit'
      Log.create(:chan => u.channel.to_s, :user => u.user.nick.downcase, :message => "leaving #{u.channel.to_s}", :time => Time.now.to_s)
    elsif a == 'say'
      Log.create(:chan => u.channel.to_s, :user => u.user.nick.downcase, :message => "saying \"#{u.message}\"", :time => Time.now.to_s)
    end
  end
end

def seen(u, nick)
  ActiveRecord::Base.connection_pool.with_connection do
    if nick == bot.nick
      u.reply "That's me!"
    elsif nick == u.user.nick
      u.reply "That's you!"
    elsif !Log.where(chan: u.channel.to_s, user: nick.downcase).last.nil?
      q = Log.where(chan: u.channel.to_s, user: nick.downcase).last
      u.reply "#{nick} was last seen #{q[:message]} #{(Time.now - Time.parse("#{q[:time]}")).duration} ago."
    else
      u.reply "I haven't seen #{nick}"
    end
  end
end

def list(u)
  User(u.user.nick).send('!tvdb <name of show>: Searches TVDB for specified show. Eg. !tvdb the simpsons')
  User(u.user.nick).send('!tvrage <name of show>: Searches TVRAGE for specified show. Eg. !tvrage the simpsons')
  User(u.user.nick).send('!tv <name of show>: Searches both TVDB and TVRAGE for specified show. Eg. !tv the simpsons')
  User(u.user.nick).send('!movie <name of movie>: Searches IMDB and RT for a specified movie. Eg. !movie spiderman')
  User(u.user.nick).send('!issues: Reports amount of open issues and unverified bugs.')
  User(u.user.nick).send('!trakt <user>: Returns watched stats for the inputted user. Eg. !trakt senseye')
  User(u.user.nick).send('!seen <user>: the last message sent by inputted user as well as when it was sent. Eg. !seen tehspede')
end