require "phant_rb/version"
require 'rest_client'
require 'pp'
require 'hashie'

module PhantRb
  class Client
    def initialize(public_key, opts = {})
      @opts = {
        base_url: 'http://data.sparkfun.com/'
      }.merge(opts)
      @public_key = public_key
      
      stream_info = stream()
      
      if stream_info.stream.has_key?('_doc')
        details = stream_info.stream._doc
      elsif stream_info.stream.has_key?('fields')
        details = stream_info.stream
      end
      
      @title       = details.title
      @description = details.description
      @fields      = details.fields
      @created     = details.date
    end

    def log(*data)
      conn = rest_conn 'input'
      @last_response = conn.post URI.encode_www_form(@fields.zip(data))
      Hashie::Mash.new(JSON.parse(@last_response.body))
    end

    def stream
      conn = rest_conn 'streams'
      response = conn.get
      Hashie::Mash.new(JSON.parse(response.body))
    end

    def get(params = {})
      conn = rest_conn 'output', params
      response = conn.get
      JSON.parse response.body
    end

    def stats
      conn = rest_conn 'stats'
      response = conn.get
      Hashie::Mash.new(JSON.parse(response.body))
    end

    def clear
      conn = rest_conn 'input'
      response = conn.delete
      Hashie::Mash.new(JSON.parse(response.body))
    end

    def rate_limits
      unless !@last_response.nil? && @last_response.headers.has_key?(:x_rate_limit_remaining)
        raise "No rate limit headers found. PhantRb::Client#log must be called before this."
      end
      Hashie::Mash.new(@last_response.headers)
    end

    private
      def rest_conn(type, params = nil)
        url = case type
              when 'stats' then URI.join @opts[:base_url], "/output/", "#{@public_key}/stats.json"
              else
                if params.nil?
                  URI.join @opts[:base_url], "/#{type}/", "#{@public_key}.json"
                else
                  URI.join @opts[:base_url], "/#{type}/", "#{@public_key}.json?" + URI.encode_www_form(params)
                end
              end

        RestClient::Resource.new url.to_s,
          {:headers => {'Phant-Private-Key' => @opts[:private_key]}}
      end
  end
end
