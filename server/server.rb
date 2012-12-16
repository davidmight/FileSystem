require 'rubygems'
require 'drb'
require 'mysql'
require 'pathname'
require 'drb/ssl'
require 'socket'
require 'json'

require_client_cert = true
DIRECTORY_HOST = 'localhost'
DIRECTORY_PORT = 2000
SERVER_URI = "druby://localhost:8787"

class Server
    attr_accessor :filename, :currentFiles

    def initialize(fname)
      @mutex = Mutex.new
      @filename = fname
      @currentFiles = mapDirectory(@filename)
      socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
      json_str = {"type" => "initServer", "uri" => SERVER_URI, "files" => @currentFiles}.to_json
      socket.puts json_str
      socket.close
    end
    
    def downloadFile(file)
      fileContent = nil
      @mutex.synchronize do
        f = open(file, "rb")
        fileContent = f.read
        f.close
      end
      puts "DOWNLOAD"
      return fileContent
    end
    
    def uploadFile(dest, fileData)
      @mutex.synchronize do
        destFile = File.open(dest, "wb")
        destFile.print fileData
        if !@currentFiles.include? dest
          updateDirectory(dest)
        end
        destFile.close
      end
      puts "UPLOAD"
    end
    
    def updateDirectory(file)
      @currentFiles.push(file)
      directory_service = DRbObject.new_with_uri(DIRECTORY_URI)
      directory_service.update(SERVER_URI, file)
      
      socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
      json_str = {"type" => "update", "uri" => SERVER_URI, "file" => file}.to_json
      socket.puts json_str
      socket.close
    end
    
    def mapDirectory(dir)
      files = getDirFiles(dir)
      folders = Pathname.new(dir).children.select {|c| c.directory? }
      if !folders.empty?
        folders.each do |folder|
          files = files + mapDirectory(folder.cleanpath)
        end
      end
      return files
    end
    
    def getDirFiles(dir)
      return Dir.glob(dir+"*.*")
    end

end

config = Hash.new
config[:verbose] = true
config[:SSLPrivateKey] = OpenSSL::PKey::RSA.new File.read("certs/localhost/localhost_keypair.pem")
config[:SSLCertificate] =
  OpenSSL::X509::Certificate.new File.read("certs/localhost/cert_localhost.pem")

if require_client_cert then
  config[:SSLVerifyMode] = OpenSSL::SSL::VERIFY_PEER |
                           OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
  config[:SSLCACertificateFile] = "certs/CA/cacert.pem"
  config[:SSLVerifyCallback] = proc do |ok, store|
    p [ok, store.error_string]
    ok
  end
end

server_object=Server.new("files/")

$SAFE = 0   # disable eval() and friends

DRb.start_service(SERVER_URI, server_object, config)

DRb.thread.join