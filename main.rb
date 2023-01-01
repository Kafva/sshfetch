#!/usr/bin/env ruby
require 'net/ssh'
require 'optparse'
require 'json'

LINUX_LOGOS = {
  'arch'    =>  "\e[94m \e[0m",
  'gentoo'  =>  "\e[37m \e[0m",
  'debian'  =>  "\e[91m \e[0m",
  'ubuntu'  =>  "\e[93m \e[0m",
  'alpine'  =>  "\e[94m \e[0m",
  'fedora'  =>  "\e[94m \e[0m"
}.freeze

# Each command should return one line of text (expect '<cmd>: ...' for errors)
UNAME_CMD = 'uname -rms'

# !! No trailing newline !!
MACOS_HW_CMD = 'system_profiler SPHardwareDataType -json -detailLevel mini | tr -d "\n"'

LINUX_OS_CMD = 'grep "^ID=" /etc/os-release' 

# Add newline on success
LINUX_DEVTREE_CMD = 'cat /sys/firmware/devicetree/base/model && echo'
LINUX_HW_CMD = 'cat /sys/devices/virtual/dmi/id/board_{name,version} 2>&1 | tr "\n" " "'

def info *args
    print "\e[34m>>>\e[0m "
    puts args
end

def parse_os_release(out)
  unless out.start_with?('grep: /etc/os-release: ')
      name = out.split('=')[1]
      LINUX_LOGOS[name]
  end
end

def parse_macos_info(out)
  unless out.include?(': command not found: system_profiler')
      # Exclude output of next command: 'grep: /etc/os-release ...'
      json_end = out.split('').rindex('}')
      JSON.parse(out[0..json_end])['SPHardwareDataType'][0]['machine_model']
  end
end

def open_ssh_connection host
    Net::SSH.start(host) do |ssh|
        out = ssh.exec! [UNAME_CMD, MACOS_HW_CMD, LINUX_OS_CMD,
                         LINUX_DEVTREE_CMD, LINUX_HW_CMD, ].join(';')
        outlist = out.split("\n")

        # warn outlist
        # warn '=========='

        uname   = outlist[0]
        hw_info = parse_macos_info(outlist[1])

        if hw_info.nil?
            logo = parse_os_release(outlist[2])
            hw_info  = !outlist[3].start_with?('cat: /sys') ? 
                       outlist[3] : outlist[4]
        else
            logo = "\e[97m \e[0m"
        end

        puts "#{logo} #{hw_info} #{uname}"
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
