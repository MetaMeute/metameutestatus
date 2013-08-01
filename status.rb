# encoding: UTF-8
require 'rubygems'
require 'sqlite3'
require 'sinatra/base'
require 'time_diff'
require 'builder'
require 'json'
require 'sinatra/jsonp'
require 'yaml'

class StatusApp < Sinatra::Base
  helpers Sinatra::Jsonp

  config = YAML.load_file('config.yml')

  helpers do
    def h(text)
      Rack::Utils.escape_html(text)
    end
    def getstatus
      # Alle status der letzten Woche
      since = Time.now.getutc - 60*60*24*7
      status = DB.execute("SELECT * FROM status WHERE timestamp > ? ORDER BY timestamp DESC LIMIT 20", since.to_s)
      if status.length == 0
          status = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 2")
      end
      return status
    end
    def getmessages(status)
      # und nur Messages, die zu den gefundenen Status passen
      messages = DB.execute("SELECT * FROM messages WHERE timestamp > ? ORDER BY timestamp LIMIT 20", status[-1]["timestamp"])
      return messages
    end
    def getdata(status, messages)
      if !status
        status = getstatus()
      end
      if !messages
        messages = getmessages(status)
      end
      @data = messages.concat(status)
      @data.sort_by! { |k| k["timestamp"] }
      return @data
    end
  end

  configure do
    DB = SQLite3::Database.new("status.db")
    DB.results_as_hash = true
  end

  get '' do
    redirect url('/')
  end

  get '/' do
    @page_title = config["title"]
    @door_open = 0
    @duration = nil

    status = getstatus()
    messages = getmessages(status)
    @data = getdata(status, messages)

    state = nil

    @data.each do |d|
      if d.has_key? "door_open"
        state = d["door_open"]
      else
        d["door_open"] = state
      end
    end

    @data.reverse!

    statusS = Array.new status
    statusS.unshift nil

    (statusS.zip status).each do |d, dPrev|
      if d != nil and dPrev != nil
        if d['door_open'] != dPrev['door_open']
          start = d['timestamp'] + " UTC"
          @duration = Time.diff(Time.now(), start, '%h:%m')[:diff]
          break
        end
      end
    end

    begin
      @door_open = status[0]['door_open']
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

    DB.execute("INSERT INTO messages (id, timestamp, message) VALUES (NULL,datetime('now'), ?)", message)
    redirect url('/')
  end

  post '/door' do
    door_open = params[:door_open]

    if door_open.nil? then
      halt 400
    end

    DB.execute("INSERT INTO status (id, timestamp, door_open) VALUES (NULL,datetime('now'), ?)", door_open)
    redirect url('/')
  end

  get '/rss' do
    @page_title = config["title"]
    @data = getdata(false, false)
    @data.reverse!

    builder :rss
  end

  get '/json' do
    status = getstatus()
    messages = getmessages(status)

    content_type 'application/json'
    { :status => status, :messages => messages }.to_json
  end

  get '/spaceapi.json' do
    headers['Cache-Control']  = "no-cache"
    headers['Access-Control-Allow-Origin'] = "*"

    @data = getstatus()
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
