require 'reverb/feed_monitor/version'
require 'yaml'
require 'net/http'
require 'uri'
require 'json'

module Reverb
  module FeedMonitor
    def self.start!
      token = API.fetch_access_token
      client = API::Client.new(token)
      listings = client.feed
      require 'rubygems'; require 'pry'; binding.pry
    end

    module API
      AUTH_URI = URI('https://reverb.com/oauth/token')

      def self.fetch_access_token
        client_id     = Configuration.client_id
        client_secret = Configuration.client_secret
        form = {
          "grant_type" => "client_credentials",
          "client_id" => "#{client_id}",
          "client_secret" => "#{client_secret}",
          "scope" => "read_lists"
        }
        res = Net::HTTP.post_form(AUTH_URI, form)
        JSON.parse(res.body)['access_token']
      end

      module Models
        class Listing
          attr_accessor :price, :make, :model, :title, :link

          def initialize(data)
            data.each do |k, v|
              send("#{k}=", v) if respond_to? k
            end
            link = data['_links']['web']['href']
          end

          def price=(data)
            @price = data.is_a?(Hash) ? data['amount'].to_f : data
          end
        end
      end

      class Client
        BASE_URI = 'https://reverb.com/api'

        def initialize(token)
          @auth = "Bearer #{token}"
        end

        def feed
          res = get '/my/feed'
          res['listings'].map { |l| Models::Listing.new(l) }
        end

        def get(uri)
          uri = URI(File.join(BASE_URI, uri))
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          req = Net::HTTP::Get.new(uri.request_uri, 'Authorization' => @auth)
          http.set_debug_output($stderr)
          res = http.request req
          JSON.parse(res.body)
        end
      end
    end

    module Configuration
      def self.client_secret
        ensure_loaded
        @config['client_secret']
      end

      def self.client_id
        ensure_loaded
        @config['client_id']
      end

      def self.ensure_loaded
        do_load unless loaded?
      end

      def self.do_load
        @config = YAML.load_file('.env.yml')
      end

      def self.loaded?
        !!@loaded
      end
    end
  end
end
