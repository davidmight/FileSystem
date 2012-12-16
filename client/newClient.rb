require 'sinatra'
require 'open-uri'
require 'drb'
require 'drb/ssl'
require 'socket'
require 'json'

send_cert=true
# The URI to connect to
DIRECTORY_HOST = 'localhost'
DIRECTORY_PORT = 2000

load 'dir_list.rb'

enable :sessions

def download(server, path, dest_path)
  file_data = server.downloadFile(path)
  dest_file = File.open(dest_path, "wb")
  dest_file.print file_data
  dest_file.close
end

def upload(server, path, src_path)
  src_file = open(src_path, "rb")
  fileContent = src_file.read
  server.uploadFile(path, fileContent)
  src_file.close  
end

def getFileList
  socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
  json_str = {"type" => "getFileList"}.to_json
  socket.puts json_str
  #puts socket.gets
  file_list = []
  while line = socket.gets
    file_list.push(line)
  end
  socket.close
  return file_list
end

def queryFile(file)
  socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
  json_str = {"type" => "updateFile", "file" => file}.to_json
  socket.puts json_str
  server_list = []
  while line = socket.gets
    server_list.push(line)
  end
  socket.close
  return server_list
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

post '/form' do
  "You submitted"
end

post '/jqueryfiletree/content' do
  @results = getFileList
  puts @results
  erb :jquerytree, :layout => false
end