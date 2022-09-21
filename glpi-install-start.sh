#!/bin/bash

# Generate self-signet certificates
/opt/scripts/gen-selfsigned.sh

# GLPI Repo Urls
REPO_GLPI="https://api.github.com/repos/glpi-project/glpi/releases/tags/"
LATEST_GLPI="https://api.github.com/repos/glpi-project/glpi/releases/latest"

# GLPI Version control
[[ ! "$VERSION_GLPI" ]] \
	&& VERSION_GLPI=$(curl -s ${LATEST_GLPI} | grep tag_name | cut -d '"' -f 4)

# Adjust according to your PHP installation
if [[ -z "${TIMEZONE}" ]]; then echo "TIMEZONE is unset"; 
else 
echo "date.timezone = \"$TIMEZONE\"" > /etc/php/8.2/apache2/conf.d/timezone.ini;
echo "date.timezone = \"$TIMEZONE\"" > /etc/php/8.2/cli/conf.d/timezone.ini;
fi

SRC_GLPI=$(curl -s ${REPO_GLPI}${VERSION_GLPI} | jq .assets[0].browser_download_url | tr -d \")
TAR_GLPI=$(basename ${SRC_GLPI})

# Work dirs
GLPI_DIR=glpi
GLPI_DIR_PREV="${GLPI_DIR}.prev"
WEB_PATH=/var/www/html/

#Check if TLS_REQCERT is present
if !(grep -q "TLS_REQCERT" /etc/ldap/ldap.conf)
then
	echo "TLS_REQCERT isn't present"
    echo -e "TLS_REQCERT\tnever" >> /etc/ldap/ldap.conf
fi

#Download and installation of GLPI from official repo if necessary
if [ "$(ls ${WEB_PATH}${GLPI_DIR})" ]; then
    echo "Checking installed version..."
    INSTLD_VERSION=`cat "${WEB_PATH}${GLPI_DIR}/VERSION_GLPI"`
    echo "Installed version: $INSTLD_VERSION"
    echo "To be installed version: $VERSION_GLPI"
    
    if [ "$INSTLD_VERSION" != "$VERSION_GLPI" ]; then 
	    echo "GLPI is already installed on local volume. Backing up previous install and installing the new one..."
        mv ${WEB_PATH}${GLPI_DIR} ${WEB_PATH}${GLPI_DIR_PREV}
        wget -P ${WEB_PATH} ${SRC_GLPI}
	    tar -xzf ${WEB_PATH}${TAR_GLPI} -C ${WEB_PATH}
        rm -Rf ${WEB_PATH}${TAR_GLPI}
        # Setting version flag
        echo "${VERSION_GLPI}" > ${WEB_PATH}${GLPI_DIR}/VERSION_GLPI
        # Recovering glpicrypt.key from previous install if existent (need to recover db data from previous installs)
        cp -fp ${WEB_PATH}${GLPI_DIR_PREV}/config/glpicrypt.key ${WEB_PATH}${GLPI_DIR}/config/
        # Recovering user files from previous install
        cp -rfp ${WEB_PATH}${GLPI_DIR_PREV}/files/* ${WEB_PATH}${GLPI_DIR}/files/
	chown -R www-data:www-data ${WEB_PATH}${GLPI_DIR}
    else
        echo "Same version of GLPI is already installed. Doing nothing."
    fi
else
    echo "Installing new GLPI..."
	wget -P ${WEB_PATH} ${SRC_GLPI}
	tar -xzf ${WEB_PATH}${TAR_GLPI} -C ${WEB_PATH}
	rm -Rf ${WEB_PATH}${TAR_GLPI}
    echo "${VERSION_GLPI}" > ${WEB_PATH}${GLPI_DIR}VERSION_GLPI
	chown -R www-data:www-data ${WEB_PATH}${GLPI_DIR}
fi

# Configuration of VHost / Apache
#echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf
#echo -e "<VirtualHost *:443>\n\tSSLEngine on \n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

#Add scheduled task by cron and enable
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

# Start cron service
service cron start

# Apache module activation
a2enmod rewrite && a2enmod ssl && service apache2 restart && service apache2 stop

# Lauch of Apache2 for the conteiner
/usr/sbin/apache2ctl -D FOREGROUND
