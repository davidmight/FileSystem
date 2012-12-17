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
      #@currentFiles = mapDirectory(@filename)
      @currentFiles = list_dir("/Users/david/Documents/ruby/filesystem/server/", @filename)
      socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
      json_str = {"type" => "initServer", "uri" => SERVER_URI, "files" => @currentFiles}.to_json
      socket.puts json_str
      socket.close
    end
    
    def downloadFile(file)
      fileContent = nil
      puts file
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
        destFile = File.open(dest, "a+")
        destFile.print fileData
        if !@currentFiles.include? dest
          updateDirectory(dest)
        end
        destFile.close
      end
      puts "UPLOAD"
    end
    
    def updateDirectory(file)
      ext = File.extname(file)
      newFile = {:file_ext => "#{ext[1..ext.length-1]}", :abs_file => "/" + file, :rel_file => File.basename(file) }
      @currentFiles.push(newFile)
      #directory_service = DRbObject.new_with_uri(DIRECTORY_URI)
      #directory_service.update(SERVER_URI, file)
      
      socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
      json_str = {"type" => "update", "uri" => SERVER_URI, "file" => newFile}.to_json
      socket.puts json_str
      socket.close
    end

    def list_dir(root, path, show_hidden = false)
      results = []
      Dir.foreach("#{root + path}") do |x|
        full_path = root + path + '/' + x
        unless x == '.' || x == '..'
          unless !show_hidden && x[0] == '.'
            if File.directory?(full_path)
              results << { :file_ext => "folder", :abs_dir =>  "#{path}#{x}/", :rel_dir => "#{x}" }
            else
              ext = File.extname(full_path)
              results << { :file_ext => "#{ext[1..ext.length-1]}", :abs_file => "#{path}#{x}", :rel_file => "#{x}" }
            end
          end
        end
      end
      return results
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

server_object=Server.new("/files/")

$SAFE = 0   # disable eval() and friends

DRb.start_service(SERVER_URI, server_object, config)

DRb.thread.join