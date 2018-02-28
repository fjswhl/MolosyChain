require 'websocket-eventmachine-client'

EM.run do

    ws = WebSocket::EventMachine::Client.connect(:uri => 'ws://0.0.0.0:8080')
  
    ws.onopen do
      puts "Connected"
    end
  
    ws.onmessage do |msg, type|
      puts "Received message: #{msg}"
    end
  
    ws.onclose do |code, reason|
      puts "Disconnected with status code: #{code}"
    end
  
    EventMachine.next_tick do
      ws.send "Hello Server!"
    end
  
  end