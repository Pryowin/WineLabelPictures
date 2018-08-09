
require 'net/https'
require 'uri'
require 'open-uri'
require 'open_uri_redirections'
require 'json'
require 'CSV'
require 'pathname'
require 'yaml'

WRITE_BINARY = "wb"

$base_uri  = "https://api.cognitive.microsoft.com"
$path = "/bing/v7.0/images/search"
yaml_filename = 'winelabels.yml'
expected_bing_key_length = 32

def file (file_name)
  filename = Pathname.new(file_name)
  unless filename.exist?
    puts "Unable to find #{file_name}"
    abort
  end
  filename
end

def build_term (bottle)
  space = " ".encode("UTF-16LE")
  bottle_lit = " bottle".encode("UTF-16LE")
  if bottle[:name] == ""
    term = bottle[:winery] + space + bottle[:grapes] + bottle_lit
  else
    term = bottle[:winery] + space + bottle[:name] +  bottle_lit
  end
  term
end

def get_image_url(term)
  uri = URI($base_uri + $path + "?q=" + URI.encode(term) + URI.escape("&count=1"))
  request = Net::HTTP::Get.new(uri)
  request['Ocp-Apim-Subscription-Key'] = $accessKey
  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(request)
  end
  response
end

def save_image(response,term)
  parsed = JSON.parse(response.body)
  if parsed != nil && parsed['value'] != nil && parsed['value'][0] != nil
    img = parsed['value'][0]['contentUrl']
    ext = File.extname(img)
    filename = "#{$image_path}#{term}#{ext}"
    begin
      download = open(img, allow_redirections: :all)
      IO.copy_stream(download,filename)
    rescue => err
      puts "Error: #{filename}"
      puts err.class.name
      puts err.message
    end
  end
end

config = YAML.load_file(yaml_filename)
$accessKey = config['accessKey']
$user_path = config['userPath']
input_csv = config['csv']
api_limit_delay = config['apiLimitDelay']

$download_path = $user_path + "Downloads/"
$image_path = $user_path + "Pictures/WineLabels/"
csv_filename = $download_path + input_csv

if $accessKey.length != expected_bing_key_length then
    puts "Invalid Bing Search API subscription key!"
    puts "Please paste yours into the YML file."
    abort
end

unless File.exist?(csv_filename) then
  puts "File #{csv_filename} does not exist"
  abort
end

# output_path = file($image_path)

csvoptions = {headers:true, header_converters: :symbol, encoding:'bom|UTF-16LE'}
CSV.foreach(csv_filename, csvoptions) do |bottle|
  term = build_term(bottle).encode(Encoding::UTF_8)
  response = get_image_url(term)
  save_image(response,term)
  sleep api_limit_delay
end
