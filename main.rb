#!/usr/bin/env ruby
require 'net/ssh'
require 'optparse'
require 'json'

LINUX_LOGOS = {
    'arch' => "\e[94m \e[0m",
    'gentoo' => "\e[37m \e[0m",
    'debian' => "\e[91m \e[0m",
    'ubuntu' => "\e[93m \e[0m",
    'alpine' => "\e[94m \e[0m",
    'fedora' => "\e[94m \e[0m"
}.freeze

PREFIX     = '├──'.freeze
PREFIX_END = '└──'.freeze

UNAME_CMD = 'uname -rms'.freeze

# !! No trailing newline !!
MACOS_HW_CMD = 'system_profiler SPHardwareDataType -json -detailLevel mini | tr -d "\n"'.freeze

LINUX_OS_CMD = 'grep "^ID=" /etc/os-release'.freeze

LINUX_HW_CMD = 'cat /sys/firmware/devicetree/base/model 2>/dev/null
                cat /sys/devices/virtual/dmi/id/{sys_vendor,board_{name,version}} 2>/dev/null | 
                  tr "\n" " "'.freeze

def info *args
    print "\e[34m>>>\e[0m "
    puts args
end

def thread_main host, opts
    Net::SSH.start(host, nil, { :timeout => opts[:timeout] }) do |ssh|
        out = ssh.exec! [UNAME_CMD, MACOS_HW_CMD, LINUX_OS_CMD,
                         LINUX_HW_CMD].join(';')
        outlist = out.split("\n")

        uname   = outlist[0]
        osname  = uname.split(' ')[0]

        case osname
        when 'Darwin'
            logo = "\e[97m \e[0m"
            # Exclude output of next command: 'grep: /etc/os-release ...'
            json_end = outlist[1].split('').rindex('}')
            json_data = JSON.parse(outlist[1][0..json_end])
            hw_info = json_data['SPHardwareDataType'][0]['machine_model']
        when 'FreeBSD'
            logo = "\e[91m \e[0m"
        when 'OpenBSD'
            logo = "\e[93m \e[0m"
        when 'NetBSD'
            logo = "\e[93m \e[0m"
        when 'Linux'
            name = outlist[2].split('=')[1]
            logo = LINUX_LOGOS[name]
            hw_info = outlist[3]
        else
            return # Silent fail
        end

        host_str = opts[:names] ? "(\e[97m#{host}\e[0m)" : ''

        parts = [logo, hw_info, uname, host_str].select{ |s| not s.nil? }

        Thread.current[:out] = parts.join(' ').gsub(/\s+/, ' ')
    end
end

#==============================================================================#
options = {
    :targets => [],
    :ignore => [],
    :timeout => 1,
    :names => false,
    :verbose => false
}

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
    opts.on('-wSECONDS', '--wait=SECONDS',
            "Connection timeout (default #{options[:timeout]} sec)") do |t|
        options[:timeout] = t.to_i
    end
    opts.on('-n', '--names',
            'Include hostnames in output') do |_|
        options[:names] = true
    end
    opts.on('-v', '--verbose', 'Run verbosely') do |_|
        options[:verbose] = true
    end
end

begin
    parser.parse!
rescue StandardError => e
    puts e.message, parser.help
    exit 1
end

threads = []
hsts = []

# 1. Parse ssh_config
File.readlines("#{Dir.home}/.ssh/config").each do |line|
    next unless line.downcase.start_with?('host ')

    hostname = line.split(' ')[1]

    next if options[:ignore].include?(hostname)
    next unless options[:targets].count.zero? || options[:targets].include?(hostname)

    hsts << hostname
end

# 2. Create one thread per host
hsts.each do |h|
    threads << Thread.new do 
      begin
        thread_main h, options 
      rescue Net::SSH::ConnectionTimeout
        options[:verbose] and info "#{h}: timed out"
      rescue Errno::ENETUNREACH
        options[:verbose] and info "#{h}: network unreachable"
      rescue Net::SSH::Proxy::ConnectError
        options[:verbose] and info "#{h}: proxy connect error"
      end
    end
end

# 3. Print output
threads.each_with_index do |thread,i|
  thread.join
  unless thread[:out].nil?
    prefix = i == hsts.length-1 ? PREFIX_END : PREFIX
    puts "#{prefix} #{thread[:out]}"
  end
end
