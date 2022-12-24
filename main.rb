#!/usr/bin/env ruby
require 'net/ssh'

# 1. Parse ssh_config
# 2. Create one thread per host
# 3. Print.

def get_sysinfo(session)
    session.open_channel do |channel|
        channel.on_data do |_ch, data|
            puts "[got data] -> #{data}"
        end
        channel.exec 'uname'
    end
end

def open_ssh_connection(host)
    Net::SSH.start(host) do |session|
        get_sysinfo session
        session.loop
    end
end

def main
    open_ssh_connection('vel')
end

#==============================================================================#
main
