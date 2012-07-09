# contents of app.rb
require 'rubygems'
require 'sqlite3'
require 'logger'
require 'sinatra/base'

class StatusApp < Sinatra::Base

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
  end

  configure do 
    LOGGER = Logger.new('sinatra.log')
    DB = SQLite3::Database.new("status.db")
    DB.results_as_hash = true
  end

  get '/' do
    @page_title = page_title
    @data = DB.execute("SELECT * FROM status ORDER BY timestamp DESC LIMIT 10")
    @door_open = 0 
    begin
      @door_open = @data[0]['door_open']
    rescue
      @door_open = 0 
    end
    erb :index
  end

  post '/' do
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
               params[:message], "paul", door_open)
    redirect '/'
  end

end

StatusApp.run!
