#!/bin/sh

export THREADS=$1
export MEMORY=$2
export FARMER_KEY=$3
export POOL_KEY=$4
export STORJ_ACCESS=$5
export STORJ_BUCKET=$6

# update system and install deps
sudo apt update
sudo apt upgrade -y
sudo apt-get install tmux iftop git -y

# install storj uplink
curl -L https://github.com/storj/storj/releases/latest/download/uplink_linux_amd64.zip -o uplink_linux_amd64.zip
unzip -o uplink_linux_amd64.zip
chmod 755 uplink
sudo mv uplink /usr/local/bin/uplink
rm uplink_linux_amd64.zip

# setup storj uplink
uplink import $STORJ_BUCKET $STORJ_ACCESS

# install zenith
curl -s https://api.github.com/repos/bvaisvil/zenith/releases/latest | grep browser_download_url | grep linux | cut -d '"' -f 4 | wget -qi -
rm zenith.x86_64-unknown-linux-musl.tgz.sha256
mv zenith.x86_64-unknown-linux-musl.tgz zenith.linux.tgz
tar xvf zenith.linux.tgz
chmod +x zenith
sudo mv zenith /usr/local/bin
rm zenith.linux.tgz

# go home and install chia
cd ~
git clone https://github.com/Chia-Network/chia-blockchain.git -b latest --recurse-submodules
cd chia-blockchain
sh install.sh

# activate and init chia
. ./activate
chia init
cd ..

# install plotman
sudo mkdir -p /home/ubuntu/tmpplots
sudo chmod 0777 /home/ubuntu/tmpplots
sudo mkdir -p /home/ubuntu/finishedplots
sudo chmod 0777 /home/ubuntu/finishedplots
sudo mkdir -p /home/chia/chia/logs
sudo chmod 0777 /home/chia/chia/logs
pip install --force-reinstall git+https://github.com/ericaltendorf/plotman@main
mkdir -p  /home/ubuntu/.config/plotman

# plotman config
cat >/home/ubuntu/.config/plotman/plotman.yaml <<EOL

# Options for display and rendering
user_interface:
        # Call out to the stty program to determine terminal size, instead of
        # relying on what is reported by the curses library.   In some cases,
        # the curses library fails to update on SIGWINCH signals.  If the
        # `plotman interactive` curses interface does not properly adjust when
        # you resize the terminal window, you can try setting this to True.
        use_stty_size: True
# Where to plot and log.
directories:
        # One directory in which to store all plot job logs (the STDOUT/
        # STDERR of all plot jobs).  In order to monitor progress, plotman
        # reads these logs on a regular basis, so using a fast drive is
        # recommended.
        log: /home/chia/chia/logs
        # One or more directories to use as tmp dirs for plotting.  The
        # scheduler will use all of them and distribute jobs among them.
        # It assumes that IO is independent for each one (i.e., that each
        # one is on a different physical device).
        #
        # If multiple directories share a common prefix, reports will
        # abbreviate and show just the uniquely identifying suffix.
        tmp:
                #- /mnt/tmp/00
                #- /mnt/tmp/01
                #- /mnt/tmp/02
                #- /mnt/tmp/03
                - /home/ubuntu/tmpplots
        # Optional: Allows overriding some characteristics of certain tmp
        # directories. This contains a map of tmp directory names to
        # attributes. If a tmp directory and attribute is not listed here,
        # it uses the default attribute setting from the main configuration.
        #
        # Currently support override parameters:
        #     - tmpdir_max_jobs
        #tmp_overrides:
                # In this example, /mnt/tmp/00 is larger than the other tmp
                # dirs and it can hold more plots than the default.
                #"/home/remotewin/plot":
                        #tmpdir_max_jobs: 6
        # Optional: tmp2 directory.  If specified, will be passed to
        # chia plots create as -2.  Only one tmp2 directory is supported.
        # tmp2: /mnt/tmp/a
        # One or more directories; the scheduler will use all of them.
        # These again are presumed to be on independent physical devices,
        # so writes (plot jobs) and reads (archivals) can be scheduled
        # to minimize IO contention.
        dst:
                #- /mnt/dst/00
                #- /mnt/dst/01
                - /home/ubuntu/finishedplots
        # Archival configuration.  Optional; if you do not wish to run the
        # archiving operation, comment this section out.
        #
        # Currently archival depends on an rsync daemon running on the remote
        # host, and that the module is configured to match the local path.
        # See code for details.
        archive:
                #rsyncd_module: plots
                #rsyncd_path: /plots
                #rsyncd_bwlimit: 80000  # Bandwidth limit in KB/s
                #rsyncd_host: myfarmer
                #rsyncd_user: chia
                # Optional index.  If omitted or set to 0, plotman will archive
                # to the first archive dir with free space.  If specified,
                # plotman will skip forward up to 'index' drives (if they exist).
                # This can be useful to reduce io contention on a drive on the
                # archive host if you have multiple plotters (simultaneous io
                # can still happen at the time a drive fills up.)  E.g., if you
                # have four plotters, you could set this to 0, 1, 2, and 3, on
                # the 4 machines, or 0, 1, 0, 1.
                #   index: 0
# Plotting scheduling parameters
scheduling:
        # Run a job on a particular temp dir only if the number of existing jobs
        # before tmpdir_stagger_phase_major tmpdir_stagger_phase_minor
        # is less than tmpdir_stagger_phase_limit.
        # Phase major corresponds to the plot phase, phase minor corresponds to
        # the table or table pair in sequence, phase limit corresponds to
        # the number of plots allowed before [phase major, phase minor]
        tmpdir_stagger_phase_major: 1
        tmpdir_stagger_phase_minor: 1
        # Optional: default is 1
        tmpdir_stagger_phase_limit: 4
        # Don't run more than this many jobs at a time on a single temp dir.
        tmpdir_max_jobs: 12
        # Don't run more than this many jobs at a time in total.
        global_max_jobs: 12
        # Don't run any jobs (across all temp dirs) more often than this.
        global_stagger_m: 45
        # How often the daemon wakes to consider starting a new plot job
        polling_time_s: 20
# Plotting parameters.  These are pass-through parameters to chia plots create.
# See documentation at
# https://github.com/Chia-Network/chia-blockchain/wiki/CLI-Commands-Reference#create
plotting:
        k: 32
        e: False             # Use -e plotting option
        n_threads: $THREADS       # Threads per job
        n_buckets: 128       # Number of buckets to split data into
        job_buffer: $MEMORY     # Per job memory
        # If specified, pass through to the -f and -p options.  See CLI reference.
        farmer_pk: $FARMER_KEY
        pool_pk: $POOL_KEY
EOL

cd ~
wget https://raw.githubusercontent.com/ovsoinc/chia-automation/main/splitter
wget https://raw.githubusercontent.com/ovsoinc/chia-automation/main/plot-watcher
chmod +x splitter
chmod +x plot-watcher

# start tmux and plotting
tmux new \; \
  send-keys 'zenith' C-m \; \
  new-window \; \
  send-keys 'htop' C-m \; \
  new-window \; \
  send-keys 'sudo iftop' C-m \; \
  new-window \; \
  send-keys 'cd ~/chia-blockchain' C-m \; \
  send-keys '. ./activate' C-m \; \
  send-keys 'cd ~' C-m \; \
  send-keys 'plotman interactive' C-m \; \
  new-window \; \
  send-keys 'cd ~' C-m \; \
  send-keys '/home/ubuntu/splitter' C-m \; \
  new-window \; \
  send-keys '/home/ubuntu/plot-watcher /home/ubuntu/threads/thread0' C-m \; \
  split-window -v \;\
  send-keys '/home/ubuntu/plot-watcher /home/ubuntu/threads/thread1' C-m \; \
  new-window \; \
  send-keys '/home/ubuntu/plot-watcher /home/ubuntu/threads/thread2' C-m \; \
  split-window -v \;\
  send-keys '/home/ubuntu/plot-watcher /home/ubuntu/threads/thread3' C-m \; \
  new-window \; \
  send-keys '/home/ubuntu/plot-watcher /home/ubuntu/threads/thread4' C-m \; \
