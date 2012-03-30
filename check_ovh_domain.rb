#!/usr/bin/ruby
# The intention of this Ryby script is to test
# expiration of ovh domains through their API
#
# (c) Mobile Devices, 2012.
# (c) Benjamin Vialle, 2012.
#
# 0 ; OK
# 1 ; WARNING
# 2 ; CRITICAL
# 3 ; UNKNOWN
#
# Nagios needs messages to be printed on $stdout instead of $sterr

begin
  # in order to use SOAP API access
  require 'savon'
  # in order to log
  require 'logger'
  # nokogiri parser
  require 'nokogiri'
  # in order to parse console arguments
  require 'getoptlong'
rescue LoadError => e
  $stderr.puts "Required library not found: '#{e.message}'."
  exit(2)
end

OPTS = GetoptLong.new(
      [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
      [ '--debug', '-d', GetoptLong::OPTIONAL_ARGUMENT ],
      [ '--warning', '-w', GetoptLong::OPTIONAL_ARGUMENT ],
      [ '--critical', '-c', GetoptLong::OPTIONAL_ARGUMENT ]
    )

class DOMAIN

  HTTPI.log = false
  HTTPI::Adapter.use = :net_http
  Nori.parser = :nokogiri
  Savon.configure do |config|
    config.log = false
    config.soap_version = 2
  end
  WSDL_URI    = "https://www.ovh.com/soapi/soapi-re-1.34.wsdl"
  LOGIN       = 'xxxxxxx-ovh'
  PASSWORD    = 'xxxxxxxx'
  LANGUAGE    = 'fr'
  MULTISESSION = false

  client = Savon::Client.new do
    wsdl.document = DOMAIN::WSDL_URI
  end

  # Nagios needs to have logging messages printed to stdout
  log = Logger.new(STDOUT)
  # Set the log level here
  log.level = Logger::INFO

  begin
    expirations = {}

    response = client.request :wsdl, :login do
      soap.body = {
        nic:          DOMAIN::LOGIN,
        password:     DOMAIN::PASSWORD,
        language:     DOMAIN::LANGUAGE,
        multisession: DOMAIN::MULTISESSION
      }
    end

    session = response[:login_response][:return]

    if ARGV.length == 0
      response = client.request :wsdl, :domain_list do
        soap.body = {
          session: session,
        }
      end

      domains = response.to_hash[:domain_list_response][:return][:item]
    else
      domains = ARGV
    end

    domains.each do |domain|
      response = client.request :wsdl, :domain_info do
        soap.body = {
          session: session,
          domain: domain
        }
      end
      expirations[domain] = response.to_hash[:domain_info_response][:return][:expiration]
    end

    expirations.each do |domain, expiration|
      if (Time.parse(expiration.to_s) - Time.parse(DateTime.now.to_s)) > 2592000
        puts "WHOIS OK: Expires #{expiration.to_s} at ovh (#{domain})"
        exit 0 if ARGV.length == 1
      elsif (Time.parse(expiration.to_s) - Time.parse(DateTime.now.to_s)) > 1296000
        puts "WHOIS WARNING: Expires #{expiration.to_s} at ovh (#{domain})"
        exit 1 if ARGV.length == 1
      else
        puts "WHOIS CRITICAL: Expires #{expiration.to_s} at ovh (#{domain})"
        exit 2 if ARGV.length == 1
      end
    end

  rescue Savon::SOAP::Fault => fault
    log.error fault.to_s
  end
end
