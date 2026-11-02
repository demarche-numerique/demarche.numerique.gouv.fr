# frozen_string_literal: true

class IPService
  class << self
    def ip_trusted?(ip) = ip_in_networks?(ip, ENV['TRUSTED_NETWORKS'])

    # `networks`: CIDRs separated by spaces, "10.0.0.0/8 192.168.0.0/16"
    def ip_in_networks?(ip, networks)
      ip_address = parse_address(ip)

      networks.to_s.split.filter_map { parse_address(it) }.any? { it.include?(ip_address) }
    end

    private

    def parse_address(address)
      begin
        IPAddr.new(address)
      rescue
        nil
      end
    end
  end
end
