require 'rubygems'
require 'drb/drb'
require 'mysql'

DIRECTORY_URI="druby://localhost:8788"

class DirectoryServer
    
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
          fileList.push(row[0])
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
            server_uri = db.query("SELECT uri FROM Servers WHERE serverId='#{row[1]}'").fetch_row
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
end

FRONT_OBJECT=DirectoryServer.new

$SAFE = 1   # disable eval() and friends

DRb.start_service(DIRECTORY_URI, FRONT_OBJECT)
DRb.thread.join