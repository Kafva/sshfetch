#!/usr/bin/env ruby
require 'net/ssh'
require 'optparse'

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
    options = {}
    options[:targets] = []
    options[:ignore] = []

    parser = OptionParser.new do |opts|
        opts.banner = "usage: #{File.basename($PROGRAM_NAME)} [options]"
        opts.on('-tTARGETS', '--targets=TARGETS',
                'Comma seperated string of hosts to connect to') do |t|
            options[:targets] = t.split(',')
        end
        opts.on('-iTARGETS', '--ignore=TARGETS',
                'Comma seperated string of hosts to ignore') do |t|
            options[:ignore] = t.split(',')
        end
    end

    begin
        parser.parse!
    rescue StandardError => e
        puts e.message, parser.help
        exit 1
    end

    # 1. Parse ssh_config
    File.readlines("#{Dir.home}/.ssh/config").each do |line|
        next unless line.downcase.start_with?('host ')

        hostname = line.split(' ')[1]

        next unless !options[:ignore].include?(hostname) &&
                    (options[:targets].count.zero? || options[:targets].include?(hostname))

        # 2. Create one thread per host
        info hostname
        # open_ssh_connection('vel')
    end
    # 3. Print.
end

#==============================================================================#
main
