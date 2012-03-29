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
  # nokogiri parser
  require 'nokogiri'
  # in order to parse console arguments
  require 'getoptlong'
  # action_view to calculate time remaining before warning
  require 'action_view'
  include ActionView::Helpers::DateHelper
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
    wsdl.document = 'http://www.ovh.com/soapi/soapi-re-1.34.wsdl'
  end

  begin
    expirations = {}

    response = client.request :wsdl, :login do
      soap.body = {
        nic: 'xxxxxxxx',
        password: 'xxxxxxxx',
        language: 'fr',
        multisession: false
      }
    end

    session = response[:login_response][:return]

    response = client.request :wsdl, :domain_list do
      soap.body = {
        session: session,
      }
    end

    domains = response.to_hash[:domain_list_response][:return][:item]

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
      puts "#{domain}: #{expiration.to_s} - #{distance_of_time_in_words_to_now(expiration)}"
    end

  rescue Savon::SOAP::Fault => fault
    log fault.to_s
  end
end
