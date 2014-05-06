# -*- coding: utf-8 -*-
#
# = Cinch GithubCommits plugin
# This plugin uses the HttpServer plugin for Cinch in order
# to implement a simple service that understands GitHub’s
# post-commit webhook (see https://help.github.com/articles/post-receive-hooks).
# When a POST request arrives, it will be parsed and a summary
# of the push results will be echoed to all channels Cinch
# currently has joined.
#
# == Dependencies
# * The HttpServer plugin for Cinch
#
# == Configuration
# Currently none.
#
# == Author
# Marvin Gülker (Quintus)
#
# == License
# A Cinch plugin listening for GitHub’s post-receive hooks.
# Copyright © 2012 Marvin Gülker
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'date'
require 'json'
require 'google_url_shortener'
require_relative 'http_server'
require_relative 'settings'

class Cinch::GithubCommits
  include Cinch::Plugin
  extend Cinch::HttpServer::Verbs

  Google::UrlShortener::Base.api_key = $googleapikey

  post '/github_commit' do
    halt 400 unless params[:payload]

    info = JSON.parse(params[:payload])

    unless info['commits'].nil?
      author = info['commits'].last['author']['username']
      oid = info['commits'].last['id'][0..7]
      desc = info['commits'].last['message']
      url = Google::UrlShortener::Url.new(:long_url => info['compare'])

      if info['commits'].count > 1
        bot.channels.each{|c| c.send("[COMMIT][#{info['ref'].split('/')[2]}] #{author} commited #{info['commits'].count} new commit(s). The latest one, \"#{oid}: #{desc.lines.first.chomp}\". URL: #{url.shorten!}")}
      else
        bot.channels.each{|c| c.send("[COMMIT][#{info['ref'].split('/')[2]}] #{author} commited \"#{oid}: #{desc.lines.first.chomp}\". URL: #{url.shorten!}")}
      end
    end

    unless info['issue'].nil?
      if info['action'] == 'opened'
        user = info['sender']['login']
        title = info['issue']['title']
        url = Google::UrlShortener::Url.new(:long_url => info['issue']['html_url'])

        bot.channels.each{|c| c.send("[ISSUE][##{info['issue']['number']}] #{user} opened a new issue: \"#{title}\" URL: #{url.shorten!}")}
      end
      if info['action'] == 'closed'
        user = info['sender']['login']
        title = info['issue']['title']
        url = Google::UrlShortener::Url.new(:long_url => info['issue']['html_url'])

        bot.channels.each{|c| c.send("[ISSUE][##{info['issue']['number']}] #{user} closed issue: \"#{title}\" URL: #{url.shorten!}")}
      end
      if info['action'] == 'reopened'
        user = info['sender']['login']
        title = info['issue']['title']
        url = Google::UrlShortener::Url.new(:long_url => info['issue']['html_url'])

        bot.channels.each{|c| c.send("[ISSUE][##{info['issue']['number']}] #{user} reopened an issue: \"#{title}\" URL: #{url.shorten!}")}
      end
    end

    204
  end

end
