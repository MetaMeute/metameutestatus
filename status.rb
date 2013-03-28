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

    status = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 10")
    messages = DB.execute("SELECT * FROM messages ORDER BY timestamp DESC LIMIT 10")

    @data = messages.concat(status)
    @data.sort_by! { |k| k["timestamp"] }

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
          start = d['timestamp']
          @duration = Time.diff(Time.now(), start, '%h:%m')[:diff]
          break
        end
      end
    end

    begin
      @door_open = data[0]['door_open']
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
    status = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 10")
    messages = DB.execute("SELECT * FROM messages ORDER BY timestamp DESC LIMIT 10")

    @data = messages.concat(status)
    @data.sort_by! { |k| k["timestamp"] }.reverse!

    builder :rss
  end

  get '/json' do
    @status = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 10")
    @messages = DB.execute("SELECT * FROM messages ORDER BY timestamp DESC LIMIT 10")

    content_type 'application/json'
    { :status => @status, :messages => @messages }.to_json
  end

  get '/spaceapi.json' do
    @data = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 10")
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
