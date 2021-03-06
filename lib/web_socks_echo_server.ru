$:.push File.expand_path("../../lib", __FILE__)
require "web_socks/websocket"

class EchoServer

  def call(env)
    socket = WebsocketRails::Core::WebSocket.new(env, ["echo"], ping: 10)
    socket.onmessage = lambda do |event|
      puts "message received"
      socket.send(event.data)
    end
    socket.onclose = lambda do |event|
      socket.close
    end
    socket.rack_response
  end

  def log(*args)
  end

  def listen(port, backend, ssl = false)
    case backend
    when :puma
      events = Puma::Events.new(StringIO.new, StringIO.new)
      binder = Puma::Binder.new(events)
      binder.parse(["tcp://0.0.0.0:#{port}"], self)
      @server = Puma::Server.new(self, events)
      @server.binder = binder
      @server.run

    when :thin
      Rack::Handler.get('thin').run(self, :Port => port) do |s|
        if ssl
          s.ssl = true
          s.ssl_options = {
            :private_key_file => File.expand_path('../server.key', __FILE__),
            :cert_chain_file  => File.expand_path('../server.crt', __FILE__)
          }
        end
        @server = s
      end
    end
  end

  def stop
    case @server
    when Puma::Server then @server.stop(true)
    else @server.stop
    end
  end
end

run EchoServer.new
