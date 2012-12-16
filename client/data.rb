require 'drb'
require 'drb/ssl'

send_cert=true

host = "localhost"
SERVER_URI = "drbssl://localhost:8787"
DIRECTORY_URI = ARGV.shift || "drbssl://localhost:8788"

def upload(server, path, src_path)
  src_file = open(src_path, "rb")
  fileContent = src_file.read
  server.uploadFile(path, fileContent)
  src_file.close  
end

config = Hash.new
config[:SSLVerifyMode] = OpenSSL::SSL::VERIFY_PEER |
                         OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
config[:SSLCACertificateFile] = "certs/CA/cacert.pem"
config[:SSLVerifyCallback] = lambda { |ok, store|
  p [ok, store.error_string]
  ok
}

if send_cert then
  config[:SSLPrivateKey] = OpenSSL::PKey::RSA.new File.read("certs/david/david_keypair.pem")
  config[:SSLCertificate] = OpenSSL::X509::Certificate.new File.read("certs/david/cert_david.pem")
end

# Start a local DRbServer to handle callbacks.
#
# Not necessary for this small example, but will be required
# as soon as we pass a non-marshallable object as an argument
# to a dRuby call.
DRb.start_service(nil, nil, config)

service = DRbObject.new nil, SERVER_URI
directory_service = DRbObject.new nil, DIRECTORY_URI

puts directory_service.getFileList
file = "files/test2.txt"

server = directory_service.updateFile(file)

server_service = DRbObject.new_with_uri(server[0])
upload(server_service, "files/result.txt", "client/result.txt")