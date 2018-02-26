require 'groupme'
require 'open-uri'
require 'uri'
require 'json'
require 'pry'

GMImage = Struct.new :url, :sender_name, :timestamp, :text

module Util
  def self.get_fileext(groupme_url)
    hostname = URI(groupme_url).hostname 
    case hostname
    when 'v.groupme.com'
      ext_matcher = %r(/\w+\.\w+\.(?<ext>\w+)$)
    when 'i.groupme.com'
      ext_matcher = %r(/\w+\.(?<ext>\w+)\.\w+$)
    else
      raise "Unrecognized attachment hostname #{hostname}"
    end
    ext_matcher.match(groupme_url)[:ext]
  end
end

class GMArchiver
  def initialize(token)
    @client = GroupMe::Client.new(:token => token)
    puts "Welcome, #{@client.me[:name]}."
  end

  def prompt_for_group
    raise 'Cannot re-select a different group.' if @selected_group
    puts @client.groups.each_with_index.map {|g, i| "#{i + 1}: #{g[:name]}"}.join("\n")
    selection = STDIN.gets.chomp!.to_i
    @selected_group = @client.groups[selection - 1]
  end

  def archive_group
    raise 'Must select a group before archiving!' unless @selected_group
    messages_bundles = @client.messages(@selected_group[:id], {}, true)
    # File.write('msgs.json', messages.to_json)
    # messages_bundles = Hashie::Array.new(JSON.parse(File.read('msgs.json')))#[20]]
    @group_images = []
    messages_bundles.each do |messages|
      messages.each do |m|
        m['attachments'].select {|a| %w[image video].include? a['type']}
          .each {|i| @group_images << GMImage.new(i['url'], m['name'], m['created_at'], m['text'])}
      end
    end
  end

  def download_images
    FileUtils.mkdir_p './images/'
    @group_images.each do |image|
      puts "Downloading #{image.url}"
      IO.copy_stream(open(image.url), "./images/#{image.timestamp}.#{Util::get_fileext(image.url)}")
    end
  end

end

if __FILE__ == $0
  raise 'Need to provide GroupMe API token' if ARGV.empty?
  gma = GMArchiver.new ARGV[0]
  gma.prompt_for_group
  gma.archive_group
  gma.download_images
end
