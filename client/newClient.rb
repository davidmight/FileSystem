require 'sinatra'
require 'open-uri'
require 'drb'
require 'drb/ssl'
require 'socket'
require 'json'
require 'haml'
require 'pathname'

class LRUCache
  
  def initialize(size = 10)
    @size = size
    @store = {}
    @lru = []
  end
  
  def set(key, value = nil)
    value = yield if block_given?
    @store[key] = value
    set_lru(key)
    @store.delete(@lru.pop) if @lru.size > @size
    value
  end
  
  def get(key)
    set_lru(key)
    if !@store.key?(key) && block_given?
      set(key, yield)
    else
      @store[key]
    end
  end
  
  def delete(key)
    @store.delete(key)
    @lru.delete(key)
  end
  
  private
    def set_lru(key)
      @lru.unshift(@lru.delete(key) || key)
    end
end

cache = LRUCache.new(4)

send_cert=true
# The URI to connect to
DIRECTORY_HOST = 'localhost'
DIRECTORY_PORT = 2000

LOCKING_HOST = 'localhost'
LOCKING_PORT = 2001

enable :sessions

def download(server, path, dest_path)
  socket = TCPSocket.open(LOCKING_HOST, LOCKING_PORT)
  json_str = {"type" => "gainLock", "file" => "/" + path}.to_json
  socket.puts json_str
  
  file_data = server.downloadFile(path)
  dest_file = File.open(dest_path, "a+")
  dest_file.print file_data
  dest_file.close
  
  json_str = {"type" => "releaseLock", "file" => "/" + path}.to_json
  socket.puts json_str
  socket.close
end

def upload(server, path, content)
  socket = TCPSocket.open(LOCKING_HOST, LOCKING_PORT)
  json_str = {"type" => "gainLock", "file" => "/" + path}.to_json
  socket.puts json_str
  
  server.uploadFile(path, content)
  
  json_str = {"type" => "releaseLock", "file" => "/" + path}.to_json
  socket.puts json_str
  socket.close
end

def delete(server, path)
  socket = TCPSocket.open(LOCKING_HOST, LOCKING_PORT)
  json_str = {"type" => "gainLock", "file" => "/" + path}.to_json
  socket.puts json_str
  
  server.deleteFile(path)
  
  json_str = {"type" => "releaseLock", "file" => "/" + path}.to_json
  socket.puts json_str
  socket.close
end

def getFileList
  socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
  json_str = {"type" => "getFileList"}.to_json
  socket.puts json_str
  #puts socket.gets
  file_list = []
  while line = socket.gets
    newFile = JSON.parse(line)
    #puts "NEWFILE: #{newFile}"
    file_list.push(newFile)
  end
  socket.close
  return file_list
end

def queryFile(file)
  puts "GETTING SERVER"
  socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
  json_str = {"type" => "findFile", "file" => file}.to_json
  puts "FILE: #{json_str}"
  socket.puts json_str
  server = socket.gets
  socket.close
  return server
end

def getServer
  socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
  json_str = {"type" => "getServer"}.to_json
  socket.puts json_str
  server = socket.gets
  socket.close
  return server
end

config = Hash.new
config[:SSLVerifyMode] = OpenSSL::SSL::VERIFY_PEER
config[:SSLCACertificateFile] = "certs/CA/cacert.pem"
config[:SSLVerifyCallback] = lambda { |ok, store|
  p [ok, store.error_string]
  ok
}

if send_cert then
  config[:SSLPrivateKey] = OpenSSL::PKey::RSA.new File.read("certs/david/david_keypair.pem")
  config[:SSLCertificate] = OpenSSL::X509::Certificate.new File.read("certs/david/cert_david.pem")
end

DRb.start_service

# Set utf-8 for outgoing
before do
  headers "Content-Type" => "text/html; charset=utf-8"
end

get '/' do
  erb :index
end

post '/download' do
  download_file = params['downloadFile']
  server = queryFile(download_file)
  if !server.empty?
    server_service = DRbObject.new_with_uri(server)
    download_file[0] = ''
    download(server_service, download_file, File.expand_path(".") + "/downloads/" + File.basename(download_file))
  else
    puts "No server, yo"
  end
  redirect "/"
end

post '/delete' do
  delete_file = params['deleteFile']
  server = queryFile(delete_file)
  if !server.empty?
    server_service = DRbObject.new_with_uri(server)
    delete_file[0] = ''
    delete(server_service, delete_file)
  else
    puts "No server, yo"
  end
  redirect "/"
end

post '/upload' do
  server = getServer
  if !server.empty?
    server_service = DRbObject.new_with_uri(server)
    upload(server_service ,"files/" + params['uploadedFile'][:filename] ,params['uploadedFile'][:tempfile].read)
  else
    puts "No server, yo"
  end
  redirect "/"
end

post '/jqueryfiletree/content' do
  @results = getFileList
  
  erb :jquerytree, :layout => false
end