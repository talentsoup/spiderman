require 'nokogiri'
require 'open-uri'
require 'csv'
require 'geokit'

include Geokit::Geocoders

MAPS_CONFIG = YAML::load(File.open('maps.yml'))

Geokit::Geocoders::google = MAPS_CONFIG['api_key']

COMPANY_NAME = 0
EMAIL        = 1
WEBSITE      = 2
PHONE        = 3
CITY_STATE   = 4
CATEGORIES   = 5

def parse_result_node(the_node)
  company_name = the_node.css('div[@class="addressinfo"]//h2').first.content
 
  email_nodes = the_node.css('a[@class="email"]')
  email_addresses = email_nodes.nil? ? "" : email_nodes.collect{|email_node| email_node.content}.join("; ")
  
  website_nodes = the_node.css('a[@class="http"]')
  websites_addresses = website_nodes.nil? ? "" : website_nodes.collect{|website| "http://" + website.content}.join("; ")

  phone_nodes = the_node.css('div[@class="phone ar12grey"]')
  phone_numbers = phone_nodes.nil? ? "" : phone_nodes.collect{|phone| phone.content}.join("; ")

  city_state_node = the_node.css('div[@class="address"]').first
  city_state = ""
  
  unless city_state_node.nil?
    geo = GoogleGeocoder.geocode(city_state_node.content)
    city_state = "#{geo.city.nil? ? geo.district : geo.city}-#{geo.state}" unless geo.nil?
  end

  categories = the_node.css('h6').css('a').collect{|category| category.content}.join("; ")
  
  puts "Finished parsing #{company_name}..."
  
  sleep(3)

  [company_name, email_addresses, websites_addresses, phone_numbers, city_state, categories]
end


results = Array.new

for page_number in 1..115
  url_to_parse = "http://www.photosourcedirectory.com/search_results.php?txtSearch=production&optCountry=45&rowsPerPage=20&optSortBy=relevancy&page=#{page_number}"
  doc = Nokogiri::HTML(open(url_to_parse))

  doc.css('div[@class="searchbg_blue"]').each do |container|
    results << parse_result_node(container)
  end

  doc.css('div[@class="searchbg_white"]').each do |container|
    results << parse_result_node(container)
  end
end

CSV.open("contacts.csv", "wb") do |csv|
  csv << ["Company Name", "Emails", "Websites", "Phone Numbers", "City/State", "Categories"]
  results.each { |x| csv << [x[COMPANY_NAME], x[EMAIL], x[WEBSITE], x[PHONE], x[CITY_STATE], x[CATEGORIES]] }
end

puts "Parsing complete."