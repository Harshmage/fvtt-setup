#!/bin/bash

WEBHOST="mywebserver.com"
CONTACTEMAIL="my@email.com"

if [ ! -d /usr/games/FoundryVTT ]; then
	apt update
	apt upgrade -y
	apt install curl wget certbot nginx python3-certbot-nginx
	NVMVER=$(curl --silent "https://api.github.com/repos/nvm-sh/nvm/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
	wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVMVER/install.sh" | bash
	exec $SHELL
	nvm install --lts
	npm install node@latest -g
	npm install pm2 -g
	# Create the folder structure for flagging this section as complete
	if [ ! -d /usr/games/FoundryVTT ]; then
		mkdir /usr/games/FoundryVTT
	fi
	if [ ! -d /usr/games/FoundryVTTData ]; then
		mkdir /usr/games/FoundryVTTData
	fi
	reboot
fi

# Install FoundryVTT and if restoring data, extract the zip file
read -p "Input your Timed URL for FoundryVTT from your Purchased Licenses page on https://foundryvtt.com/ : " FVTTINSTALL
wget -O /usr/games/FoundryVTT/foundryvtt.zip $FVTTINSTALL
unzip /usr/games/FoundryVTT/foundryvtt.zip -d /usr/games/FoundryVTT
rm /usr/games/FoundryVTT/foundryvtt.zip
if [ -f "/usr/games/FoundryVTTData/foundryvttdata.zip" ]; then
	unzip /usr/games/FoundryVTTData/foundryvttdata.zip -d /usr/games/FoundryVTTData
	rm /usr/games/FoundryVTTData/foundryvttdata.zip
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
