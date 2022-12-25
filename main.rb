#!/usr/bin/env ruby
require 'net/ssh'


def info *args
    print "\e[34m>>>\e[0m "
    puts args
end

def get_sysinfo session
    session.open_channel do |channel|
        channel.on_data do |_ch, data|
            puts "[got data] -> #{data}"
        end
        channel.exec 'uname'
    end
end

def open_ssh_connection host
    Net::SSH.start(host) do |session|
        get_sysinfo session
        session.loop
    end
end

def main
    # 1. Parse ssh_config
    File.readlines("#{Dir.home}/.ssh/config").each do |line|
        if line.downcase.start_with?('host ')
            hostname = line.split(' ')[1]
            # 2. Create one thread per host
            info hostname
            # open_ssh_connection('vel')
        end
    end
    # 3. Print.
end

#==============================================================================#
main
