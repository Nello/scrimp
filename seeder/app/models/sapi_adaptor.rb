require 'rubygems'
require 'rest_client'
 
class SapiAdaptor
  @@uri = 'http://api.sensis.com.au/ob-20110511/test'
  @@params = { :key => '72vpnyj7ahwab3ub2pf7gtp2' }
 
  # api.sensis.com.au/ob-20110511/test/search?key=<key> 
  def self.search(options={})
    pages = (options[:pages] || 1).to_i
    query = options[:query].downcase
    options[:rows] = 50
    total_pages = 1

    entries = []
    (1..pages).each do |n|
      options[:page] = n

	  if n <= total_pages
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
      entry[:categories] = categories(result)
      entry[:keywords] =  keywords(result)
      entry[:address] = address(result)
      entry[:latitude] = latitude(result)
      entry[:longitude] = longitude(result)
      entry[:description] = description(result)
      entry[:phone] = phone(result)
      entry[:url] = url(result)

      acc << entry
    end
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
  	nil
  end

  def self.clean(ary)
    ary.select { |e| e.length > 3 }.map { |e| e.downcase.gsub(/---*/, ' ') }.uniq
  end
end
