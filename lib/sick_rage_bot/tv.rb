require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'google_url_shortener'

module SickRageBot
  class Tv
    attr_accessor :feed

    def initialize(n, source)
      show_name = n.split(' ', 2)[1]
      self.feed = if source == 'tvrage'
                    TvRage.new show_name
                  else
                    TheTvdb.new show_name
                  end
      if feed.valid?
        n.reply feed.to_irc_s
      else
        n.reply "#{Format(:bold, source.upcase)} - No results found."
      end
    end

    class TvBase
      attr_accessor :show_name
      def initialize(show_name)
        self.show_name = show_name
      end

      def show
        @show ||= Nokogiri::XML(open(tvurl))
      end

      def show_id
        id_element.text
      end

      def search
        @search ||= Nokogiri::XML(open(searchurl))
      end

      def tvname
        @tvname ||= show.css(name).text
      end

      def tvstatus
        @tvstatus ||= show.css(status).text
      end

      def link
      end

      def source
        self.class.to_s.split('::')[-1].upcase
      end

      def valid?
        !id_element.nil?
      end

      def to_irc_s
        str = "#{Format(:bold, "#{source} - Show:")} #{tvname} "
        str += ":: #{Format(:bold, 'Status:')} #{tvstatus} "
        str += ":: #{Format(:bold, 'Next:')} #{nexta} " unless ended?
        str += ":: URL: #{url}"
        str
      end

      # FIXME: Needs rewriting
      def nexta
        if source.downcase == 'tvrage'
          s = { :aired => 'Season > episode > airdate',
                :day => 'airday',
                :time => 'airtime' }
        else
          s = { :aired => 'Episode > FirstAired',
                :day => 'Airs_DayOfWeek',
                :time => 'Airs_Time' }
        end
        show.search(':empty').remove
        split = show.css(s[:aired]).last.text.split('-')
        if Date.valid_date?(split[0].to_i, split[1].to_i, split[2].to_i) == true and Date.parse(show.css(s[:aired]).last.text) < Date.today
          return 'No data.'
        end
        show.css(s[:aired]).each do |x|
          var = x.text.split('-')
          if Date.valid_date?(var[0].to_i, var[1].to_i, var[2].to_i) == true and Date.parse(x.text) >= Date.today
            if (Date.parse(x.text) - Date.today).to_i == 1
              return "#{x.text} #{show.css(s[:day]).text} #{show.css(s[:time]).text} (#{(Date.parse(x.text) - Date.today).to_i} day left)"
            elsif (Date.parse(x.text) - Date.today).to_i == 0
              return "#{x.text} #{show.css(s[:day]).text} #{show.css(s[:time]).text} (Today)"
            else
              return "#{x.text} #{show.css(s[:day]).text} #{show.css(s[:time]).text} (#{(Date.parse(x.text) - Date.today).to_i} days left)"
            end
          end
        end
      end
    end

    class TheTvdb < TvBase
      def url
        Google::UrlShortener::Url.new(
          long_url: 'http://thetvdb.com/?tab=series&'\
          "id=#{show_id}"
        ).shorten!
      end

      def id_element
        search.css('seriesid').first
      end

      def name
        'SeriesName'
      end

      def status
        'Status'
      end

      def searchurl
        'http://thetvdb.com/api/GetSeries.php?seriesname=' +
          CGI.escape(show_name)
      end

      def tvurl
        "http://thetvdb.com/api/#{$tvdbapikey}/series/#{show_id}/all.en.xml"
      end

      def ended?
        tvstatus == 'Canceled/Ended'
      end
    end

    class TvRage < TvBase
      def url
        Google::UrlShortener::Url.new(long_url: link).shorten!
      end

      def id_element
        search.css('showid').first
      end

      def name
        'name'
      end

      def status
        'status'
      end

      def searchurl
        'http://services.tvrage.com/feeds/search.php?show=' +
          CGI.escape(show_name)
      end

      def tvurl
        "http://services.tvrage.com/feeds/full_show_info.php?sid=#{show_id}"
      end

      def link
        show.css('Show > showlink').text
      end

      def ended?
        tvstatus == 'Ended'
      end
    end
  end
end
