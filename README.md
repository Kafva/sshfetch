# sshfetch
Fetch brief system information over SSH. A connection attempt is made for every
host in `~/.ssh/config` by default.

```bash
# Install dependencies
bundle install

# Install and run
gem build sshfetch.gemspec && gem install *.gem &&
    sshfetch --help

# ... or run directly
./bin/sshfetch --help
```
