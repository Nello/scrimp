require 'rubygems'
require 'rest_client'
 
class SapiAdaptor
  @@uri = 'http://api.sensis.com.au/ob-20110511/test'
  @@params = { :key => '72vpnyj7ahwab3ub2pf7gtp2', :rows => 50 }
 

  def self.search(options={})
    pages = (options[:pages] || 1).to_i
    query = (options[:query] || '').downcase

    entries = []
    total_pages = 1
    (1..pages).each do |n|
  	  if n <= total_pages
        options[:page] = n
        
  	    response = RestClient.get("#{@@uri}/search", { :params => options.except(:pages).merge(@@params) })
  	    json = JSON.parse(response)
  	    entries += process(query, json)

  	    total_pages = (json['totalPages'] || 1).to_i
  	  end
    end
    entries
  end

  private

  def self.process(query, json)
  	json['results'].reduce([]) do |acc, result|
      entry = {}

      entry[:search] = query
      entry[:name] = name(result)
      assign_no_nil(entry, :categories, categories(result))
      assign_no_nil(entry, :keywords, keywords(result))
      assign_no_nil(entry, :address, address(result))
      assign_no_nil(entry, :location, location(result))
      assign_no_nil(entry, :description, description(result))
      assign_no_nil(entry, :phone, phone(result))
      assign_no_nil(entry, :url, url(result))

      acc << entry
    end
  end

  def self.assign_no_nil(entry, key, value) 
    entry[key] = value if value
  end

  def self.name(result)
    result['name']
  end

  def self.categories(result) #TODO: do we need to merge categories for repeated results? (probably)
    clean (result['categories'] || {}).map { |e| e['name'] }
  end

  def self.keywords(result) #TODO: should this be product / service?
    clean (result['productKeywords'] || {}).reduce([]) { |acc,(k,v)| acc + v }
  end

  def self.address(result)
  	primaryAddress = result['primaryAddress'] || {}

    ary = []
  	addressLine = primaryAddress['addressLine']
  	ary << addressLine unless addressLine.blank?
  	ary << primaryAddress['suburb']
  	ary << primaryAddress['postcode']
  	ary << primaryAddress['state']

  	ary.compact.join(', ')
  end

  def self.location(result)
    lat = latitude(result)
    lon = longitude(result)
    "#{lat},#{lon}" if lat and lon
  end

  def self.latitude(result)
  	(result['primaryAddress'] || {})['latitude']
  end

  def self.longitude(result)
  	(result['primaryAddress'] || {})['longitude']
  end

  def self.description(result)
  	result['mediumDescriptor'] || result['shortDescriptor']
  end

  def self.phone(result)
  	result['primaryContacts'].each { |e| return e['value'] if e['type'] =~ /phone/i }
  	result['primaryContacts'].each { |e| return e['value'] if e['type'] =~ /mobile/i }
  	nil
  end

  def self.url(result)
  	result['primaryContacts'].each { |e| return e['value'] if e['type'] =~ /url/i }
  	result['detailsLink']
  end

  def self.clean(ary)
    ary.select { |e| e.length > 3 }.map { |e| e.downcase.gsub(/---*/, ' ') }.uniq
  end
end
