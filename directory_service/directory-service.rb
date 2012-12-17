require 'rubygems'
require 'mysql'
require 'json'
require 'socket'

DIRECTORY_HOST = 'localhost'
DIRECTORY_PORT = 2000

LOCKING_HOST = 'localhost'
LOCKING_PORT = 2001
    
    def initialiseServer(serverUri, files)
        begin 
          db = Mysql.connect("localhost", "root", "", "distributed")
          puts "no probs"
          server_exists = db.query("SELECT * FROM Servers WHERE uri='#{serverUri}'")
          if server_exists.num_rows == 0
            puts "server doesn't exist"
            server_insert = db.prepare "INSERT INTO Servers (uri) VALUES (?)"
            server_insert.execute serverUri
            
            server_id = db.query("SELECT serverId FROM Servers WHERE uri='#{serverUri}'").fetch_row
            
            files.each do |file|
              puts file
              file_insert = db.prepare "INSERT INTO Files (type, absPath, relPath, serverId) VALUES (?, ?, ?, ?)"
              if file["file_ext"] == "folder"
                file_insert.execute file["file_ext"], file["abs_dir"], file["rel_dir"], server_id[0]
              else
                file_insert.execute file["file_ext"], file["abs_file"], file["rel_file"], server_id[0]
              end
            end
            
          else
            puts "server exists"
          end
          server_exists.free
          
        rescue Mysql::Error => e
          puts "Oh noes! We could not connect to our database."
          puts e
          exit 1

        ensure
          db.close
          #file_insert.close
          #server_insert.close
        end
    end
    
    def findFile(file)
        capableServers = searchForFile(file)
        if !capableServers.empty?
          return capableServers[0]
        else
          puts "no capable servers"
        end
    end
    
    def getUploadServer
      begin
        
        db = Mysql.connect("localhost", "root", "", "distributed")
        
        server_uri = db.query("SELECT * FROM Servers")
        row = server_uri.fetch_row
        uploadServer = row[1]
        
      rescue Mysql::Error => e
        puts "Oh noes! We could not connect to our database."
        puts e
        exit 1
        
      ensure
        db.close
      end
      
      return uploadServer
    end
    
    def getFileList
      begin
        fileList = []
        db = Mysql.connect("localhost", "root", "", "distributed")
        files = db.query("SELECT * FROM Files")
        while row = files.fetch_row do
          if row[1] == "folder"
            newFile = {"file_ext" => row[1], "abs_dir" => row[2], "rel_dir" => row[3]}.to_json
          else
            newFile = {"file_ext" => row[1], "abs_file" => row[2], "rel_file" => row[3]}.to_json
          end
          #puts newFile
          fileList.push(newFile)
        end
        return fileList
        
      rescue Mysql::Error => e
        puts "Oh noes! We could not connect to our database."
        puts e
        exit 1
        
      ensure
        db.close
      end
      
    end
    
    def searchForFile(file)
        capableServers = []
        begin
          db = Mysql.connect("localhost", "root", "", "distributed")
          file_location = db.query("SELECT * FROM Files WHERE absPath='#{file}'")
          
          while row = file_location.fetch_row do
            server_uri = db.query("SELECT uri FROM Servers WHERE serverId='#{row[4]}'").fetch_row
            capableServers.push(server_uri[0])
          end
          
          file_location.free
          
        rescue Mysql::Error => e
          puts "Oh noes! We could not connect to our database."
          puts e
          exit 1
          
        ensure
          db.close
        end
        
        #return 0
        return capableServers
    end
    
    def update(serverUri, file)
      begin
        db = Mysql.connect("localhost", "root", "", "distributed")
        server_id = db.query("SELECT serverId FROM Servers WHERE uri='#{serverUri}'").fetch_row
        file_insert = db.prepare "INSERT INTO Files (type, absPath, relPath, serverId) VALUES (?, ?, ?, ?)"
        file_insert.execute file["file_ext"], file["abs_file"], file["rel_file"], server_id[0]
        
      rescue Mysql::Error => e
        puts "Oh noes! We could not connect to our database."
        puts e
        exit 1
        
      ensure
        db.close
      end
      
      #socket = TCPSocket.open(LOCKING_HOST, LOCKING_PORT)
      #json_str = {"type" => "fileUpdate", "file" => file["abs_file"]}.to_json
      #socket.puts json_str
      #socket.close
    end
    
    def deleteFile(serverUri, file)
      puts file
      begin
        db = Mysql.connect("localhost", "root", "", "distributed")
        file_delete = db.prepare "DELETE FROM Files WHERE absPath=?"
        file_delete.execute file
        
      rescue Mysql::Error => e
        puts "Oh noes! We could not connect to our database."
        puts e
        exit 1
        
      ensure
        db.close
      end
      
    end

server = TCPServer.open(DIRECTORY_HOST, DIRECTORY_PORT)   # Socket to listen on port 2000
loop {                          # Servers run forever
  Thread.start(server.accept) do |client|
    request = client.gets
    parsed = JSON.parse(request)
    
    case parsed["type"]
    when "initServer"
      initialiseServer(parsed["uri"], parsed["files"])
      puts "server initialised"
      
    when "findFile"
      client.puts findFile(parsed["file"])
      puts "server passed"
      
    when "getFileList"
      client.puts getFileList
      puts "file list given"
      
    when "update"
      update(parsed["uri"], parsed["file"])
      puts "file updated"
      
    when "findFileServers"
      client.puts searchForFile(parsed["file"])
      puts "servers passed"
      
    when "getServer"
      client.puts getUploadServer
      puts "gave server list"
      
    when "deletion"
      deleteFile(parsed["uri"], parsed["file"])
      puts "file deleted"
    
    else
      puts "invalid request"
    end
    
    client.close                # Disconnect from the client
  end
}