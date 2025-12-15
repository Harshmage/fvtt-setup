#!/bin/bash

WEBHOST="mywebhost.com"
CONTACTEMAIL="my@email.com"
FVTTPATH="/usr/games/FoundryVTT"
FVTTDATA="/usr/games/FoundryVTTData"
OPTIONSFILE="$FVTTDATA/Config/options.json"

function set_config() {
  local file=$1
  local key=$2
  local val=$3

  sed -i "s/\("$key":*\).*/\1\": "$val"/" $file
}

# Pre-Setup
apt update
apt upgrade -y
apt install curl wget certbot nginx python3-certbot-nginx
NVMVER=$(curl --silent "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVMVER/install.sh" | bash
exec $SHELL
nvm install --lts
npm install node@latest -g
npm install pm2 -g

# Install FoundryVTT and if restoring data, extract the zip file
if [ ! -d $FVTTPATH ]; then
	mkdir $FVTTPATH
fi
if [ ! -d $FVTTDATA ]; then
	mkdir $FVTTDATA
fi
read -p "Input your Timed URL for FoundryVTT from your Purchased Licenses page on https://foundryvtt.com/ : " FVTTINSTALL
wget -O $FVTTPATH/foundryvtt.zip $FVTTINSTALL
unzip $FVTTPATH/foundryvtt.zip -d $FVTTPATH
rm $FVTTPATH/foundryvtt.zip
read -p "If you have a zipped FoundryVTT data folder from a prior installation, you should upload it to the $FVTTDATA folder now."$'\n\nPress ENTER/RETURN to continue.'
if [ -f "$FVTTDATA/foundryvttdata.zip" ]; then
	unzip $FVTTDATA/foundryvttdata.zip -d $FVTTDATA
	rm $FVTTDATA/foundryvttdata.zip
else
	node $FVTTPATH/resources/app/main.js --dataPath=$FVTTDATA/ &
	sleep 30
	PID=$(pgrep node)
	kill $PID
	set_config $OPTIONSFILE datapath "\"\/usr\/games\/FoundryVTTData\""
	set_config $OPTIONSFILE hostname "\"$WEBHOST\""
	set_config $OPTIONSFILE port 443
	set_config $OPTIONSFILE sslCert "\"\/etc\/letsencrypt\/live\/$WEBHOST\/cert.pem\""
	set_config $OPTIONSFILE sslKey "\"\/etc\/letsencrypt\/live\/$WEBHOST\/privkey.pem\""
fi

# Use Certbot to apply an HTTPS certificate to the server using nginx
service nginx stop
rm /etc/nginx/sites-enabled/default
echo -e "server {\n    listen 80;\n    server_name $WEBHOST;\n    access_log /var/log/nginx/$WEBHOST/access.log;\n    error_log /var/log/nginx/$WEBHOST/error.log;\n}" >> /etc/nginx/sites-available/$WEBHOST
ln -s /etc/nginx/sites-available/$WEBHOST /etc/nginx/sites-enabled
mkdir -p /var/log/nginx/$WEBHOST
service nginx start
certbot --agree-tos -m $CONTACTEMAIL -d $WEBHOST --no-eff-email --nginx
service nginx stop
update-rc.d -f nginx disable

# Now start the FoundryVTT service using PM2, with crontab restart every Wednesday at 12:00am
pm2 start "node /usr/games/FoundryVTT/resources/app/main.js --dataPath=/usr/games/FoundryVTTData/" --name "foundry" --cron "0 0 * * WED"
pm2 save --force

reboot
