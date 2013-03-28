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
    
    @data = DB.execute("SELECT door_open FROM status ORDER BY timestamp DESC LIMIT 1")
    door_open = @data[0]['door_open']

    if message.nil? || message.strip.length == 0 then
      redirect '/'
    end
    message.strip!

    DB.execute("INSERT INTO status (id, message, source, timestamp, door_open) VALUES (NULL,?,'web',datetime('now'),?)",
               message, door_open)
    redirect '/'
  end

  post '/paul' do
    door_open = params[:door_open]

    if door_open == 1 then
       message = 'Keller offen'
    else
       message = 'Keller zu'
    end
   
    DB.execute("INSERT INTO status (id, message, source, timestamp, door_open) VALUES (NULL,?,'paul',datetime('now'), ?)",
               message, door_open)
  end

  get '/rss' do
    @page_title = page_title
    @data = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 10")

    builder :rss
  end

  get '/json' do
    @page_title = page_title
    @data = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 10")

    content_type 'application/json'
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

    json = YAML.load_file('status.yml')
    json[:open] = @open
    json[:lastchange] = @lastchange

    content_type 'application/json'
    jsonp json
  end

  # start the server if ruby file executed directly
  run! if app_file == $0
end
