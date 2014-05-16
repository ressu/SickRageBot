require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'google_url_shortener'
require 'json'
require 'openssl'
require_relative 'settings'

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
  issues = Nokogiri::XML(open(url)).css('td.topics-count')[4].text

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
  if u.user.authed? and $ops.include?(u.user.nick)
    if u.message.split(' ')[0] == '!op'
      if u.message.split(' ')[1].nil?
        u.channel.op(u.user.nick)
      else
        u.channel.op(u.message.split(' ')[1])
      end
    elsif u.message.split(' ')[0] == '!voice'
      if u.message.split(' ')[1].nil?
        u.channel.voice(u.user.nick)
      else
        u.channel.voice(u.message.split(' ')[1])
      end
    elsif u.message.split(' ')[0] == '!devoice'
      if u.message.split(' ')[1].nil?
        u.channel.devoice(u.user.nick)
      else
        u.channel.devoice(u.message.split(' ')[1])
      end
    elsif u.message.split(' ')[0] == '!deop'
      if u.message.split(' ')[1].nil?
        u.channel.deop(u.user.nick)
      else
        u.channel.deop(u.message.split(' ')[1])
      end
    end
  end
end