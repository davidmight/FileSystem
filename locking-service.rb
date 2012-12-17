server = TCPServer.open(LOCKING_HOST, LOCKING_PORT)   # Socket to listen on port 2000
loop {                          # Servers run forever
  Thread.start(server.accept) do |client|
    request = client.gets
    parsed = JSON.parse(request)
    
    case parsed["type"]
    when "initServer"
      initialiseServer(parsed["uri"], parsed["files"])
      puts "server initialised"
      
    client.close                # Disconnect from the client
  end
}