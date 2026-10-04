require "socket"
require "ipaddr"

module Testing
  module NetworkGuard
    class ExternalNetworkBlocked < StandardError; end

    def self.check!(host)
      return if host == "localhost"
      return if IPAddr.new(host.to_s).loopback?

      raise ExternalNetworkBlocked, "External network disabled; use a provider fake"
    rescue IPAddr::InvalidAddressError
      raise ExternalNetworkBlocked, "External network disabled; use a provider fake"
    end

    module TcpGuard
      def new(host, *args, **kwargs)
        Testing::NetworkGuard.check!(host)
        super
      end

      def open(host, *args, **kwargs, &block)
        Testing::NetworkGuard.check!(host)
        super
      end
    end

    module SocketGuard
      def connect(address)
        check_address!(address)
        super
      end

      def connect_nonblock(address, **kwargs)
        check_address!(address)
        super
      end

      private

      def check_address!(address)
        return unless [ Socket::AF_INET, Socket::AF_INET6 ].include?(Socket.sockaddr_family(address))

        _, host = Socket.unpack_sockaddr_in(address)
        Testing::NetworkGuard.check!(host)
      end
    end

    def self.install!
      require "typhoeus"
      Typhoeus::Config.block_connection = true
      TCPSocket.singleton_class.prepend(TcpGuard) unless TCPSocket.singleton_class.ancestors.include?(TcpGuard)
      Socket.prepend(SocketGuard) unless Socket.ancestors.include?(SocketGuard)
    end
  end
end
