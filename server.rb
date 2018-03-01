require 'websocket-eventmachine-server'

EM.run do

    WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 8080) do |ws|      
      ws.onopen do
        puts "Client connected"
      end
  
      ws.onmessage do |msg, type|
        puts "Received message: #{msg} #{ws.to_s}"
        ws.send msg, :type => type
      end
  
      ws.onclose do
        puts "Client disconnected"
      end
    end
  
  end