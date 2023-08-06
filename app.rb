# frozen_string_literal: true

require 'bundler'
Bundler.require

module Gmg
  class App < Sinatra::Base
    # global settings
    configure do
      set :root, File.dirname(__FILE__)
      set :public_folder, 'public'

      register Sinatra::ActiveRecordExtension
    end

    # development settings
    configure :development do
      register Sinatra::Reloader
    end

    # database settings
    set :database_file, 'config/database.yml'

    # require all models
    Dir.glob('./models/*.rb') do |model|
      require model
    end

    # require all models
    Dir.glob('./services/*.rb') do |service|
      require service
    end

    # root route
    get '/' do
      erb :index
    end

    # partials

    # helpers do
    #   def partial(navbar)
    #     erb(navbar, layout: false)
    #   end
    # end
  end
end