require 'drb/drb'

# The URI to connect to
DIRECTORY_URI="druby://localhost:8788"

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

# Start a local DRbServer to handle callbacks.
#
# Not necessary for this small example, but will be required
# as soon as we pass a non-marshallable object as an argument
# to a dRuby call.
DRb.start_service

directory_service = DRbObject.new_with_uri(DIRECTORY_URI)

#puts directory_service.getFileList
file = "files/test2.txt"

server = directory_service.updateFile(file)
if !server.empty?
  server_service = DRbObject.new_with_uri(server[0])
  upload(server_service, "files/result.txt", "client/result.txt")
else
  puts "No Server has this file"
end
