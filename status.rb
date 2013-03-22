# encoding: UTF-8
require 'rubygems'
require 'sqlite3'
require 'sinatra/base'
require 'time_diff'
require 'builder'
require 'json'
require 'sinatra/jsonp'

class StatusApp < Sinatra::Base
  helpers Sinatra::Jsonp

  helpers do
    def page_title
      'MetaMeuteStatus'
    end

    def keller_offen
      ['offen', 'auf']
    end

    def keller_zu
      ['geschlossen', 'zu']
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  configure do
    DB = SQLite3::Database.new("status.db")
    DB.results_as_hash = true
  end

  get '/' do
    @page_title = page_title
    @data = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 100")
    @door_open = 0
    @duration = nil

    dataS = Array.new @data
    dataS.unshift nil

    (dataS.zip @data).each do |d, dPrev|
      if d != nil and dPrev != nil
        if d['door_open'] != dPrev['door_open']
          start = d['timestamp']
          @duration = Time.diff(Time.now(), start, '%h:%m')[:diff]
          break
        end
      end
    end

    begin
      @door_open = @data[0]['door_open']
    rescue
      @door_open = 0
    end

    erb :index
  end

  post '/' do
    message = params[:message]
    if message.nil? || message.strip.length == 0 then
      redirect '/'
    end
    message.strip!
    source = params[:source]
    @data = DB.execute("SELECT door_open FROM status ORDER BY timestamp DESC LIMIT 1")

    door_open = 0

    begin
      door_open = params[:door_open]

      if door_open.nil? then
        door_open = @data[0]['door_open']
      end
    rescue
      door_open = 0
    end

    DB.execute("INSERT INTO status (id, message, source, timestamp, door_open) VALUES (NULL,?,?,datetime('now'), ?)",
               message, source, door_open)
    redirect '/'
  end

  get '/rss' do
    @page_title = page_title
    @data = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 10")

    builder :rss
  end

  get '/json' do
    @page_title = page_title
    @data = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 10")

    @data.to_json
  end

  get '/spaceapi.json' do
    @data = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 100")
    @open = false
    @lastchange = nil

    dataS = Array.new @data
    dataS.unshift nil

    (dataS.zip @data).each do |d, dPrev|
      if d != nil and dPrev != nil
        if d['door_open'] != dPrev['door_open']
          start = d['timestamp']
          @lastchange = Time.parse(start + " UTC").to_i
          break
        end
      end
    end

    begin
      @open = @data[0]['door_open'].to_i == 1
    rescue
      @open = false
    end

    json = {
        :api => "0.12",
        :space => "MetaMeute",
        :url => "https://metameute.de",
        :icon => {
          :open => "https://status.metameute.de/images/open.png",
          :closed => "https://status.metameute.de/images/closed.png"
        },
        :address => "Unversität zu Lübeck, Gebäude 62, Ratzeburger Allee 160, 23562 Lübeck, Germany",
        :contact => {
          :phone => "+494515005011",
          :ml => "MetaMeute@asta.uni-luebeck.de",
          :irc => "irc://irc.oftc.net/#Metameute"
        },
        :logo => "https://status.metameute.de/images/meutelogo.png",
        :feeds => [
          {:name => "blog",
           :type => "application/rss+xml",
           :url => "http://blog.metameute.de/feed/"
          },
          {:name => "status",
           :type => "application/rss+xml",
           :url => "http://status.metameute.de/rss"
          }
        ],
        :lat => 53.834372,
        :lon => 10.702268,
        :open => @open,
        :lastchange => @lastchange
      }
    jsonp json
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
