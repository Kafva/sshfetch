#!/usr/bin/env ruby
require 'net/ssh'
require 'optparse'

LINUX_LOGOS = {
  'arch'    =>  "\e[94m \e[0m",
  'gentoo'  =>  "\e[37m \e[0m",
  'debian'  =>  "\e[91m \e[0m",
  'ubuntu'  =>  "\e[93m \e[0m",
  'alpine'  =>  "\e[94m \e[0m",
  'fedora'  =>  "\e[94m \e[0m"
}.freeze

def info *args
    print "\e[34m>>>\e[0m "
    puts args
end

def open_ssh_connection host
    Net::SSH.start(host) do |ssh|
        out = ssh.exec! '
          uname -rms
          sed -nE "s/^ID=(.*)/\1/p" /etc/os-release 2>/dev/null
        '
        uname   = out.split("\n")[0]
        osinfo  = out.split("\n")[1]
        logo = LINUX_LOGOS[osinfo]

        puts "#{logo} #{uname}"
    end
end

#==============================================================================#
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

    next if options[:ignore].include?(hostname)
    next unless options[:targets].count.zero? || options[:targets].include?(hostname)

    # 2. Create one thread per host
    info hostname
    open_ssh_connection(hostname)
end
# 3. Print.
