require 'sinatra'
require 'open-uri'
require 'drb'
require 'drb/ssl'
require 'socket'
require 'json'
require 'haml'
require 'pathname'

send_cert=true
# The URI to connect to
DIRECTORY_HOST = 'localhost'
DIRECTORY_PORT = 2000

LOCKING_HOST = 'localhost'
LOCKING_PORT = 2001

load 'dir_list.rb'

enable :sessions

def download(server, path, dest_path)
  file_data = server.downloadFile(path)
  dest_file = File.open(dest_path, "a+")
  dest_file.print file_data
  dest_file.close
end

def upload(server, path, content)
  #src_file = open(src_path, "rb")
  #fileContent = src_file.read
  server.uploadFile(path, content)  
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
  json_str = {"type" => "updateFile", "file" => file}.to_json
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
  #puts "File: #{params['downloadFile']}"
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