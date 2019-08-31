#!/bin/bash

# Only run as a root user
if [ "$(sudo id -u)" != "0" ]; then
    echo "This script may only be run as root or with user with sudo privileges."
    exit 1
fi

HBAR="---------------------------------------------------------------------------------------"
BINLINK='https://github.com/genesisofficial/genesis/releases/download/v'
FIRST_TAG='genesis-'
END_TAG='-x86_64-linux-gnu.tar.gz'
GENESIS_BRANCH="master"
DEFAULT_PORT=7233
COIN_PORT=7233
DEFAULT_RPCPORT=7234
ERR=$(dpkg-query -l lsof | grep Err)
clear
if [ -z "$ERR" ]; then apt install -y lsof >/dev/null 2>&1 ; fi 

while [ -n "$(sudo lsof -i -s TCP:LISTEN -P -n | grep $DEFAULT_PORT)" ]
do
((DEFAULT_PORT--))
done
while [ -n "$(sudo lsof -i -s TCP:LISTEN -P -n | grep $DEFAULT_RPCPORT)" ]
do
((DEFAULT_RPCPORT++))
done
# import messages
source <(curl -sL https://gist.githubusercontent.com/ssowellsvt/8c83352379ab33dc5b462be1a80f156d/raw/messages.sh)



pause(){
  echo ""
  read -n1 -rsp $'Press any key to continue or Ctrl+C to exit...\n'
}

do_exit(){
  echo ""
  echo "Thank you for supporting the Genesis Network!"
  echo ""
  echo "https://genesisnetwork.io/"
  echo ""
  echo "Twitter:"
  echo "  @genx_network"
  echo ""
  echo ""
  echo "Goodbye!"
  exit 0
}

update_system(){
  echo "$MESSAGE_UPDATE"
  # update package and upgrade Ubuntu
  #sudo DEBIAN_FRONTEND=noninteractive apt -y update
  #sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade
  #sudo DEBIAN_FRONTEND=noninteractive apt -y autoremove
  sudo apt install git -y
  clear
}

install_dependencies(){
  echo "$MESSAGE_DEPENDENCIES"
  # git
  sudo apt install -y git
  # unzip for bootstrap
  sudo apt install -y unzip
  # build tools
  sudo apt install -y build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libb2-dev software-properties-common
  # boost
  sudo apt install -y libboost-all-dev
  # bdb 4.8
  sudo add-apt-repository -y ppa:bitcoin/bitcoin
  sudo apt update -y
  sudo apt install -y libdb4.8-dev libdb4.8++-dev
  # zmq
  sudo apt install -y libzmq3-dev
  clear
}

git_clone_repository(){
  echo "$MESSAGE_CLONING"
  cd
  if [ ! -d ~/genesis ]; then
    git clone https://github.com/genesisofficial/genesis.git
  fi
}

genesis_branch(){
  read -e -p "Genesis Github Branch [master]: " GENESIS_BRANCH
  if [ "$GENESIS_BRANCH" = "" ]; then
    GENESIS_BRANCH="master"
  fi
}

git_checkout_branch(){
  cd ~/genesis
  git fetch
  git checkout $GENESIS_BRANCH --quiet
  if [ ! $? = 0 ]; then
    echo "$MESSAGE_ERROR"
    echo "Unable to checkout https://www.github.com/genesisofficial/genesis/tree/${GENESIS_BRANCH}, please make sure it exists."
    echo ""
    exit 1
  fi
  make distclean
  git pull
}

autogen(){
  echo "$MESSAGE_AUTOGEN"
  cd ~/genesis
  ./autogen.sh
  clear
}

configure(){
  echo "$MESSAGE_MAKE_CONFIGURE"
  cd ~/genesis
  ./configure --without-gui
  clear
}

compile(){
  echo "$MESSAGE_MAKE"
  echo "Running compile with $(nproc) core(s)..."
  # compile using all available cores
  cd ~/genesis
  sudo make -j$(nproc) -pipe
  clear
}	  

install(){
  echo "$MESSAGE_MAKE_INSTALL"
  # install the binaries to /usr/local/bin
  cd ~/genesis
  sudo make install
  clear
}

download (){
  cd ~/genesis
  MIDLE_TAG=$(git tag --sort=-creatordate | head -1 | cut -c 2-)
  if [ -f $FIRST_TAG$MIDLE_TAG$END_TAG ]; then rm $FIRST_TAG$MIDLE_TAG$END_TAG; fi
  wget $BINLINK$MIDLE_TAG/$FIRST_TAG$MIDLE_TAG$END_TAG
  tar -xvf $FIRST_TAG$MIDLE_TAG$END_TAG
  cd $FIRST_TAG$MIDLE_TAG/bin
  if [ -f genesis-cli ]; then sudo mv genesis-cli /usr/local/bin/ ; fi
  if [ -f genesisd ]; then  sudo mv genesisd /usr/local/bin/ ; fi
  cd ~/genesis
  rm -rf $FIRST_TAG$MIDLE_TAG
}

install_sentinel(){
  echo "$MESSAGE_SENTINEL"
  # go home
  cd 
  if [ ! -d ~/sentinel ]; then
    git clone https://github.com/genesisofficial/sentinel.git
  else
    cd sentinel
    git fetch
    git checkout master --quiet
    git pull
  fi
    clear
}

install_virtualenv(){
  echo "$MESSAGE_VIRTUALENV"
  cd ~/sentinel
  # install virtualenv
  sudo apt-get install -y python-virtualenv virtualenv
  # setup virtualenv
  virtualenv venv
  venv/bin/pip install -r requirements.txt
  clear
}

configure_sentinel(){
  echo "$MESSAGE_CRONTAB"
  # create sentinel conf file
  echo "$SENTINEL_CONF" > ~/sentinel/sentinel.conf
  if [ "$IS_MAINNET" = "" ] || [ "$IS_MAINNET" = "y" ] || [ "$IS_MAINNET" = "Y" ]; then
    echo "network=mainnet" >> ~/sentinel/sentinel.conf
  else
    echo "network=testnet" >> ~/sentinel/sentinel.conf
  fi

  cd
  if [ -d /home/$GUSER/sentinel ]; then
    sudo rm -rf /home/$GUSER/sentinel
  fi
  sudo mv -f ~/sentinel /home/$GUSER
  sudo chown -R $GUSER.$GUSER /home/$GUSER/sentinel

  # create sentinel-ping
  echo "$SENTINEL_PING" > ~/sentinel-ping

  # install sentinel-ping script
  sudo mv -f ~/sentinel-ping /usr/local/bin
  sudo chmod +x /usr/local/bin/sentinel-ping

  # setup cron for genesis user
  #sudo crontab -r -u $GUSER
  sudo crontab -l -u $GUSER | grep sentinel-ping || echo "* * * * * /usr/local/bin/sentinel-ping" | sudo crontab -u $GUSER -
  
  clear
}

start_genesisd(){
  echo "$MESSAGE_GENESISD"
  #sudo service genesisd start     # start the service
  #sudo systemctl enable genesisd  # enable at boot
  su $GUSER -c 'genesisd -daemon'
  clear
}

stop_genesisd(){
  echo "$MESSAGE_STOPPING"
  if [ -f /usr/lib/systemd/system/genesisd.service ]; then  sudo service genesisd stop; fi
  ERR=$(ps -u GUSER | grep genesis)
  if [ -z "$ERR" ]; then  su $GUSER -c 'genesis-cli stop'; fi
  clear
}

bootstrap(){
  echo "$MESSAGE_BOOTSTRAP"
  read -e -p "Download bootstrap? [Y/n]:" ANSWER
   if [ -z $ANSWER ] || [ $ANSWER = 'y' ] || [ $ANSWER = 'Y' ]; then
     wget https://genxcommunityhelper.blob.core.windows.net/bootstraps/latest/bootstrap.zip
	 unzip -o bootstrap.zip -d /home/$GUSER/.genesis/main/
	 sudo chown -R $GUSER:$GUSER /home/$GUSER/.genesis/main/
	 sudo rm -R bootstrap.zip
  fi
}
  
upgrade() {
  # genesis_branch    # ask which branch to use
  clear
  install_dependencies # make sure we have the latest deps
  update_system       # update all the system libraries
  git_checkout_branch # check out our branch
  clear
  stop_genesisd       # stop genesisd if it is running
  read -e -p "Do you want compile bin files? [Y/n]:" ANSWER
if [ -z $ANSWER ] || [ $ANSWER = 'y' ] || [ $ANSWER = 'Y' ]; then
   autogen            # run ./autogen.sh
   configure          # run ./configure
   compile            # compile
   install            # install the binaries
else
   download
fi
clear

  # maybe upgrade sentinel
  if [ "$IS_UPGRADE_SENTINEL" = "" ] || [ "$IS_UPGRADE_SENTINEL" = "y" ] || [ "$IS_UPGRADE_SENTINEL" = "Y" ]; then
    install_sentinel
    install_virtualenv
    configure_sentinel
  fi

  start_genesisd      # start genesisd back up
  
  echo "$MESSAGE_COMPLETE"
  echo "Genesis Official update complete using https://www.github.com/genesisofficial/genesis/tree/${GENESIS_BRANCH}!"
  do_exit             # exit the script
}

masternode_private_key(){
  read -e -p "Masternode Private Key [$masternodeprivkey]: " MASTERNODE_PRIVATE_KEY
  if [ "$MASTERNODE_PRIVATE_KEY" = "" ]; then
    if [ "$masternodeprivkey" != "" ]; then
      MASTERNODE_PRIVATE_KEY="$masternodeprivkey"
    else
      echo "You must enter a masternode private key!";
      masternode_private_key
    fi
  fi
}

create_genesis_user(){
  echo "$MESSAGE_CREATE_USER"
  read -e -p "Input User name: " GUSER
  # create a genesis user if it doesn't exist
  grep -q -E "^$GUSER:" /etc/passwd || sudo adduser --disabled-password --gecos "" $GUSER
  #sudo adduser $GUSER
  # add alias to .bashrc to run genesis-cli as genesis user
  #grep -q "genxcli\(\)" ~/.bashrc || echo "genxcli() { sudo su -c \"genesis-cli \$*\" genesis; }" >> ~/.bashrc
  #grep -q "alias genesis-cli" ~/.bashrc || echo "alias genesis-cli='genxcli'" >> ~/.bashrc
  #grep -q "genxd\(\)" ~/.bashrc || echo "genxd() { sudo su -c \"genesisd \$*\" genesis; }" >> ~/.bashrc
  #grep -q "alias genesisd" ~/.bashrc || echo "alias genesisd='genxd'" >> ~/.bashrc
  #grep -q "genxmasternode\(\)" ~/.bashrc || echo "genxmasternode() { bash <(curl -sL genesisnetwork.io/mn-installer); }" >> ~/.bashrc
}

create_configure(){
  #echo "$MESSAGE_CONFIGURE"
  # in case it's already running because this is a re-install
  #sudo service genesisd stop
  ERR=$(ps -u GUSER | grep genesis)
  if [ -z "$ERR" ]; then  su $GUSER -c 'genesis-cli stop'; fi
  # create conf directory
  echo "$GENESIS_CONF" > ~/genesis.conf  
  sudo mkdir -p /home/$GUSER/.genesis
  sudo rm -rf /home/$GUSER/.genesis/debug.log
  sudo mv -f ~/genesis.conf /home/$GUSER/.genesis/genesis.conf
  sudo chown -R $GUSER:$GUSER /home/$GUSER/.genesis
  sudo chmod 600 /home/$GUSER/.genesis/genesis.conf
  clear
}

create_systemd_genesisd_service(){
  echo "$MESSAGE_SYSTEMD"
  crontab -u $GUSER -l > cron
  echo -e "@reboot genesisd -daemon" >> cron
  crontab -u $GUSER cron
  rm cron
  # create systemd service
  #echo "$GENESISD_SERVICE" > ~/genesisd.service
  # install the service
  #sudo mkdir -p /usr/lib/systemd/system/
  #sudo mv -f ~/genesisd.service /usr/lib/systemd/system/genesisd.service
  # reload systemd daemon
  #sudo systemctl daemon-reload
  clear
}

install_fail2ban(){
  echo "$MESSAGE_FAIL2BAN"
  sudo apt-get install fail2ban -y
  sudo service fail2ban restart
  sudo systemctl fail2ban enable
  clear
}

install_ufw(){
  echo "$MESSAGE_UFW"
#  sudo apt-get install ufw -y
#  sudo ufw default deny incoming
#  sudo ufw default allow outgoing
#  sudo ufw allow ssh
  sudo ufw allow 7233/tcp
#  yes | sudo ufw enable
  clear
}

get_masternode_status(){
  echo ""
  sudo su -c "genesis-cli mnsync status" $GUSER && \
  sudo su -c "genesis-cli masternode status" $GUSER
  echo ""
  read -e -p "Check again? [Y/n]: " CHECK_AGAIN
  if [ "$CHECK_AGAIN" = "" ] || [ "$CHECK_AGAIN" = "y" ] || [ "$CHECK_AGAIN" = "Y" ]; then
    get_masternode_status
  fi
}


clear
echo "$MESSAGE_WELCOME"
pause
clear

echo "$MESSAGE_PLAYER_ONE"
sleep 1
clear


# errors are shown if LC_ALL is blank when you run locale
if [ "$LC_ALL" = "" ]; then export LC_ALL="$LANG"; fi

# check to see if there is already a genesis user on the system
if grep -q -E "^$GUSER:" /etc/passwd; then
  clear
  echo "$MESSAGE_UPGRADE"
  echo ""
  echo "  Choose [Y]es (default) to upgrade Genesis Official on a working masternode."
  echo "  Choose [N]o to re-run the configuration process for your masternode."
  echo ""
  echo "$HBAR"
  echo ""
  read -e -p "Upgrade/Recompile Genesis Official? [Y/n]: " IS_UPGRADE
  if [ "$IS_UPGRADE" = "" ] || [ "$IS_UPGRADE" = "y" ] || [ "$IS_UPGRADE" = "Y" ]; then
    read -e -p "Upgrade Sentinel as well? [Y/n]: " IS_UPGRADE_SENTINEL
    upgrade
  fi
fi
clear

create_genesis_user

RESOLVED_ADDRESS=$(curl -s ipinfo.io/ip)

echo "$MESSAGE_CONFIGURE"
echo ""
echo "This script has been tested on Ubuntu 16.04/18.04 LTS x64."
echo ""
echo "Before starting script ensure you have: "
echo ""
echo "  - Sent 750,000 GENX to your masternode address"
echo "  - Run 'masternode genkey' and 'masternode outputs' and recorded the outputs" 
echo "  - Added masternode config file: (Can be done after this script is ready)"
echo "    - Windows — %appdata%Genesis\main\masternode.conf"
echo "    - Linux — ~/.genesis/main/masternode.conf"
echo "    - MacOS — ~/Library/Application Support/Genesis/main/masternode.conf"
echo "      - AddressAlias VPSIP:7233 MasternodePrivKey TransactionID OutputIndex"
echo "      - EXAMPLE: mn1 ${RESOLVED_ADDRESS}:7233 ctk9ekf0m3049fm930jf034jgwjfk zkjfklgjlkj3rigj3io4jgklsjgklsjgklsdj 0"
echo "  - Restarted Genesis-Qt (Can be done after this script is ready)"
echo ""
echo "Default values are in brackets [default] or capitalized [Y/N] - pressing enter will use this value."
echo ""
echo "$HBAR"
echo ""

# genesis.conf value defaults
rpcuser="genesisrpc"
rpcpassword="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"
masternodeprivkey=""
externalip="$RESOLVED_ADDRESS"
port="$DEFAULT_PORT"

# try to read them in from an existing install
if sudo test -f /home/$GUSER/.genesis/genesis.conf; then
  sudo cp /home/$GUSER/.genesis/genesis.conf ~/genesis.conf
  sudo chown $(whoami).$(id -g -n $(whoami)) ~/genesis.conf
  source ~/genesis.conf
  rm -f ~/genesis.conf
fi

RPC_USER="$rpcuser"
RPC_PASSWORD="$rpcpassword"
MASTERNODE_PORT="$port"

# genesis_branch

if [ "$externalip" != "$RESOLVED_ADDRESS" ]; then
  echo ""
  echo "WARNING: The genesis.conf value for externalip=${externalip} does not match your detected external ip of ${RESOLVED_ADDRESS}."
  echo ""
fi
read -e -p "External IP Address [$externalip]: " EXTERNAL_ADDRESS
if [ "$EXTERNAL_ADDRESS" = "" ]; then
  EXTERNAL_ADDRESS="$externalip"
fi
if [ "$port" != "" ] && [ "$port" != "$DEFAULT_PORT" ]; then
  echo ""
  echo "WARNING: The genesis.conf value for port=${port} does not match the default of ${DEFAULT_PORT}."
  echo ""
fi
read -e -p "Masternode Port [$port]: " MASTERNODE_PORT
if [ "$MASTERNODE_PORT" = "" ]; then
  MASTERNODE_PORT="$port"
fi

masternode_private_key

# Generating Random Passwords
RPC_PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

pause
clear

# genesis conf file
GENESIS_CONF=$(cat <<EOF
# RPC #
rpcuser=user
rpcpassword=$RPC_PASSWORD
rpcport=$DEFAULT_RPCPORT
rpcallowip=127.0.0.1
# General #
listen=1
server=1
daemon=1
txindex=1
maxconnections=24
debug=0
# Masternode #
masternode=1
masternodeprivkey=$MASTERNODE_PRIVATE_KEY
externalip=$EXTERNAL_ADDRESS
#masternodeaddr=$EXTERNAL_ADDRESS:$COIN_PORT
port=$MASTERNODE_PORT
# Addnodes #
addnode=mainnet1.genesisnetwork.io
addnode=mainnet2.genesisnetwork.io
EOF
)

# GENESISD_SERVICE=$(cat <<EOF
# [Unit]
# Description=Genesis Official Service
# After=network.target iptables.service firewalld.service
 
# [Service]
# Type=forking
# User=$GUSER
# ExecStart=/usr/local/bin/genesisd
# ExecStop=/usr/local/bin/genesis-cli stop && sleep 20 && /usr/bin/killall genesisd
# ExecReload=/usr/local/bin/genesis-cli stop && sleep 20 && /usr/local/bin/genesisd
 
# [Install]
# WantedBy=multi-user.target
# EOF
# )

SENTINEL_CONF=$(cat <<EOF
# genesis conf location
genesis_conf=/home/$GUSER/.genesis/genesis.conf

# db connection details
db_name=/home/$GUSER/sentinel/database/sentinel.db
db_driver=sqlite

# network
EOF
)

SENTINEL_PING=$(cat <<EOF
#!/bin/bash

~/sentinel/venv/bin/python ~/sentinel/bin/sentinel.py 2>&1 >> ~/sentinel/sentinel-cron.log
EOF
)



# update_system
install_dependencies
git_clone_repository
git_checkout_branch
clear

# run the build steps
ANSWER='y'
if [ -f /usr/local/bin/genesisd ]; then 
	read -e -p "Bin files exist. Do you recompile? [y/N]:" ANSWER
#else
	#read -e -p "Press Y for compile bin files or any key for downloading [y/N]:" ANSWER
	#if [ ! -z $ANSWER ] || [ ! $ANSWER = 'y' ] || [ ! $ANSWER = 'Y' ]; then
	#	download
	#fi
fi
if [ $ANSWER = 'y' ] || [ $ANSWER = 'Y' ]; then
   autogen
   configure
   compile
   install
fi
clear

create_configure
create_systemd_genesisd_service
bootstrap
start_genesisd
install_sentinel
install_virtualenv
configure_sentinel
# install_fail2ban
install_ufw
clear

echo "$MESSAGE_COMPLETE"
echo ""
echo "Your Genesis Masternode configuration should now be completed and running as the "genesis" user."
echo "If you see MASTERNODE_SYNC_FINISHED return to Genesis-Qt and start your node, otherwise check again."

get_masternode_status

# ping sentinel
sudo su -c "sentinel-ping" $GUSER

echo ""
echo "Masternode setup complete!"
echo ""
echo "Please run the following command to access genesis-cli from this session or re-login."
echo ""
echo "  source ~/.bashrc"
echo ""
echo "You can run genesis-cli commands as the genesis user: "
echo ""
echo "  genesis-cli -getinfo"
echo "  genesis-cli masternode status"
echo ""
echo "To update - simply type 'genxmasternode'"

cd 
rm -rf Genesis

do_exit
