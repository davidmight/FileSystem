require 'rubygems'
require 'mysql'
require 'json'
require 'socket'

DIRECTORY_HOST = 'localhost'
DIRECTORY_PORT = 2000

    
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
              file_insert = db.prepare "INSERT INTO Files (name, serverId) VALUES (?, ?)"
              file_insert.execute file, server_id[0]
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
    
    def updateFile(file)
        return searchForFile(file)
    end
    
    def getFileList
      begin
        fileList = []
        db = Mysql.connect("localhost", "root", "", "distributed")
        files = db.query("SELECT * FROM Files")
        while row = files.fetch_row do
          fileList.push(row[1])
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
          file_location = db.query("SELECT * FROM Files WHERE name='#{file}'")
          
          while row = file_location.fetch_row do
            server_uri = db.query("SELECT uri FROM Servers WHERE serverId='#{row[2]}'").fetch_row
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
        file_insert = db.prepare "INSERT INTO Files (name, serverId) VALUES (?, ?)"
        file_insert.execute file, server_id[0]
        
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
      
    when "updateFile"
      client.puts updateFile(parsed["file"])
      puts "file updated"
      
    when "getFileList"
      client.puts getFileList
      puts "file list given"
      
    when "update"
      update(parsed["uri"], parsed["file"])
      puts "file updated"
      
    else
      puts "invalid request"
    end
    
    client.close                # Disconnect from the client
  end
}