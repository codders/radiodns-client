#!/usr/bin/ruby
require 'resolv'
require 'uri'
require 'cgi'
require 'net/http'
require 'rubygems'
require 'json'
require 'stomp'

###########################
# Requirements:
# stomp (gem install stomp)
# json (gem install json)
###########################

class RadioDNSService
end

class TagService < RadioDNSService
  def initialize(host, port)
    @host = host.to_s
    @port = port.to_i
  end
  
  def register
    req = Net::HTTP.new(@host, @port)
    postdata = { :v => '1.0', :d => "00001234"}.to_json
    return req.post("/register", { :v => '1.0', :d => "00001234"}.to_json, {'content-type' => 'application/octet-stream'})
  end
 
  def to_s
    return "Tag service at: #{@root}"
  end
end

class VisService < RadioDNSService
  def initialize(host, port)
    @host = host.to_s
    @port = port.to_i
  end

  def to_s
    return "Visualisation service at #{@host}, port #{@port}"
  end

  def receive
    return @connection.receive
  end

  def connect(url)
    @connection = Stomp::Connection.open(nil, nil, @host, @port)
    @connection.subscribe("/topic/#{url}", { :ack => 'auto' })
  end
end

class EpgService < RadioDNSService
  def initialize(url_root)
    @root = url_root
  end

  def to_s
    return "EPG service at #{@root}"
  end

  def get_epg(url)
    fetch_url = "#{@root}epg?url=#{CGI.escape(url)}"
    puts "Fetching EPG from '#{fetch_url}'"
    return Net::HTTP.get URI.parse(fetch_url)    
  end
end

class RadioDNS

  def initialize
    @resolver = Resolv::DNS.new
  end

  def get_resource(service, url)
    host = URI.parse(url).host
    return @resolver.getresource("#{service}._tcp.#{host}", Resolv::DNS::Resource::IN::SRV)
  end  

  def tag(url)
    resource = get_resource('_radiotag', url)
    return TagService.new(resource.target, resource.port)
  end

  def vis(url)
    resource = get_resource('_radiovis', url)
    return VisService.new(resource.target, resource.port)
  end

  def epg(url)
    resource = get_resource('_radioepg', url)
    return EpgService.new("http://#{resource.target}:#{resource.port}/")
  end
end

URL="http://stream.capitalfm.com/show.asx?StreamID=1&web=true"
dns = RadioDNS.new
tagservice = dns.tag(URL)
visservice = dns.vis(URL)
epgservice = dns.epg(URL)

#### Attempts to retrieve EPG data
puts "Requesting EPG data"
puts epgservice.get_epg(URL)

### Attempts to register for the tag service
puts tagservice.register()

### Attempts to retreive visualisation service data
puts "Connecting to visualisation service:"
visservice.connect(URL)
puts "Waiting for message"
puts visservice.receive()
