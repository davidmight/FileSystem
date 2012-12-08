require 'rubygems'
require 'drb/drb'
require 'mysql'
require 'pathname'

DIRECTORY_URI="druby://localhost:8788"
SERVER_URI="druby://localhost:8787"

class Server
    attr_accessor :filename, :currentFiles

    def initialize(fname)
      @filename = fname
      @currentFiles = mapDirectory(@filename)
    end
    
    def downloadFile(file)
      f = open(file, "rb")
      fileContent = f.read
      f.close
      puts "DOWNLOAD"
      return fileContent
    end
    
    def uploadFile(dest, fileData)
      destFile = File.open(dest, "wb")
      destFile.print fileData
      updateDirectory(dest)
      destFile.close
      puts "UPLOAD"
    end
    
    def updateDirectory(file)
      @currentFiles.push(file)
      directory_service = DRbObject.new_with_uri(DIRECTORY_URI)
      directory_service.update(SERVER_URI, file)
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

server_object=Server.new("files/")

$SAFE = 0   # disable eval() and friends

DRb.start_service(SERVER_URI, server_object)

directory_service = DRbObject.new_with_uri(DIRECTORY_URI)

directory_service.initialiseServer(SERVER_URI, server_object.currentFiles )

DRb.thread.join