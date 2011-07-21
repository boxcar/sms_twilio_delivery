# MIT Licensed
# Author: Boxcar, http://boxcar.io | http://github.com/Boxcar
# 
# requires: em-http-request, em-websocket, twiliolib gems.
#
# Be sure to modify the SETTINGS hash and replace it with your Boxcar email, etc.

require 'rubygems'
require 'twiliolib'
require 'eventmachine'
require 'em-http'
require 'em-websocket'
require 'digest/md5'
require 'json'

SETTINGS = { acco
  :email    => 'XXXyourEmailXXX',
  :password => 'XXXyourPasswordXXX',

  :twilio => {
    :to_number     => 'xxx-xxx-xxxx',
    :from_number   => 'xxx-xxx-xxxx',
    :account_sid   => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
    :account_token => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
  }
}

EventMachine.run {
  http = EventMachine::HttpRequest.new("ws://farm.boxcar.io:8080/websocket").get :timeout => 0
 
  http.errback {
    puts "There was a problem maintaining the connection."
  }

  http.callback {
    puts "Connected!  Send yourself a notification.  Find example code at http://github.com/boxcar"
    http.send retrieve_access_token
  }

  http.stream { |msg|
    begin
      js = JSON.parse(msg)
      puts "Recieved: #{msg}"
      payload = [ js['service_name'], js['from_screen_name'], js['message'] ].join(' - ')
      deliver_sms(payload)
    rescue Exception => e
      puts "Exception: #{e}"
    end
  }

  def deliver_sms(message)
    account = Twilio::RestAccount.new(SETTINGS[:twilio][:account_sid], SETTINGS[:twilio][:account_token])

    d = {
        'From' => SETTINGS[:twilio][:from_number],
        'To' => SETTINGS[:twilio][:to_number],
        'Body' => message
    }

    begin
      resp = account.request("/2010-04-01/Accounts/#{SETTINGS[:twilio][:account_sid]}/SMS/Messages",
          'POST', d)

      resp.error! unless resp.kind_of? Net::HTTPSuccess
      puts "code: %s\nbody: %s" % [resp.code, resp.body]
    rescue Exception => e
      puts "Exception while posting to Twilio: #{e}"
      puts "code: %s\nbody: %s" % [resp.code, resp.body]
    end
  end

  def retrieve_access_token
    uri = URI.parse('https://boxcar.io/devices/sessions/access_token')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri)
    request.set_form_data({'username' => SETTINGS[:email], 'password' => SETTINGS[:password], 
        'api_key' => 'Tw7UrZT4UAKGi5fAzbl2'})
    response = http.request(request)
    response = http.start {|http| http.request(request) }
    response.body
  end
}