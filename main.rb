require 'net/ssh'

def do_ls(session)
    session.open_channel do |channel|
        channel.on_data do |_ch, data|
            puts "[got data] -> #{data}"
        end
        channel.exec 'uname'
    end
end

Net::SSH.start('vel') do |session|
    do_ls session
    session.loop
end
