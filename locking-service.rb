require 'json'
require 'socket'

DIRECTORY_HOST = 'localhost'
DIRECTORY_PORT = 2000

LOCKING_HOST = 'localhost'
LOCKING_PORT = 2001

class LockingServer
  attr_accessor :locks
  
  def initialize
    @locks = Hash.new
    socket = TCPSocket.open(DIRECTORY_HOST, DIRECTORY_PORT)
    json_str = {"type" => "getFileList"}.to_json
    socket.puts json_str
    file_list = []
    while line = socket.gets
      newFile = JSON.parse(line)
      file_list.push(newFile)
    end
    socket.close
    file_list.each do |file|
      if file["file_ext"] != "folder"
        addFile(file["abs_file"])
      end
    end
    #puts @locks
    
  end
  
  def addFile(path)
    #puts "File Added"
    @locks[path] = Mutex.new
  end
  
  def gainLock(path)
    #puts path
    if @locks.has_key?(path)
      @locks[path].lock
    else
      addFile(path)
      @locks[path].lock
      puts "File does not exist"
    end
    #puts @locks[path]
    #puts @locks[path].locked?
  end
  
  def releaseLock(path)
    #puts @locks[path]
    #puts @locks[path].locked?
    if @locks.has_key?(path)
      @locks[path].unlock
    else
      puts "File does not exist"
    end
  end
end 


locker = LockingServer.new

server = TCPServer.open(LOCKING_HOST, LOCKING_PORT)   # Socket to listen on port 2000
loop {                          # Servers run forever
  Thread.start(server.accept) do |client|
    request = client.gets
    parsed = JSON.parse(request)
    
    case parsed["type"]
    when "gainLock"
      puts "Lock request"
      locker.gainLock(parsed["file"])
      puts "Lock granted"
      request = client.gets
      parsed = JSON.parse(request)
      if parsed["type"] == "releaseLock"
        puts "Lock release request"
        locker.releaseLock(parsed["file"])
        puts "Lock released"
      else
        puts "You should be releasing brah"
      end
      
    #when "fileUpdate"
    #  locker.addFile(parsed["file"])
    #  puts "New lock"
      
    else
      puts "invalid request"
    end
      
    client.close                # Disconnect from the client
  end
}