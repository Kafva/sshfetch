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

UNAME_CMD = 'uname -rms'

LINUX_OS_CMD = 'sed -nE "s/^ID=(.*)/\1/p" /etc/os-release 2>/dev/null' 

MACOS_HW_CMD = 'system_profiler SPHardwareDataType 2> /dev/null | 
              sed -nE "s/.*Model Identifier: (.*)/ \1/p" 2> /dev/null'

LINUX_HW_CMD = 'cat /sys/firmware/devicetree/base/model 2>/dev/null ||
            cat /sys/devices/virtual/dmi/id/board_{name,version} 2> /dev/null | 
              tr "\n" " " | sed "s/None//g"'

def info *args
    print "\e[34m>>>\e[0m "
    puts args
end

def open_ssh_connection host
    Net::SSH.start(host) do |ssh|
        out = ssh.exec! [UNAME_CMD, LINUX_OS_CMD, MACOS_HW_CMD, LINUX_HW_CMD].join(';')

        uname             = out.split("\n")[0]
        linux_os_release  = out.split("\n")[1]

        macos_info        = out.split("\n")[2]


        logo = LINUX_LOGOS[linux_os_release]

        if logo.nil? and not macos_info.nil?
            logo = "\e[97m \e[0m "
        end

        puts "#{logo} #{macos_info} #{uname}"
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
