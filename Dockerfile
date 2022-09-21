#Base container
#FROM debian:11.1
FROM debian:stable-slim

LABEL org.opencontainers.image.authors="aguinaldoabbj@github"

#Use Debian noninteractive mode
ENV DEBIAN_FRONTEND noninteractive

# GLPI recommends to always use the latest available PHP, so let's add PHP8.x 3rd party repos
RUN apt update && apt install --yes --no-install-recommends \
ca-certificates \
lsb-release \ 
curl \
gnupg \
&& echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" \
   | tee /etc/apt/sources.list.d/sury-php.list \
&& curl -s https://packages.sury.org/php/apt.gpg | apt-key add -

# Install GLPI dependencies
RUN apt update \
&& apt install --yes --no-install-recommends \
apache2 \
openssl \
php8.2 \
php8.2-cli \
php-json \
php8.2-mysql \
php8.2-ldap \
php-ldap \
#php8.2-xmlrpc \ #not needed for php8
php8.2-imap \
php8.2-curl \
php8.2-gd \
php8.2-mbstring \
php8.2-xml \
php8.2-intl \
php8.2-zip \
php8.2-bz2 \
# php8.2-apcu-bc \ #not needed for php8
php-cas \
php-json \

cron \
wget \
ca-certificates \
jq \
libldap-2.4-2 \
libldap-common \
libsasl2-2 \
libsasl2-modules \
libsasl2-modules-db \
&& rm -rf /var/lib/apt/lists/*

#Copy scripts
RUN mkdir /opt/scripts
COPY *.sh /opt/scripts
RUN chmod +x /opt/scripts/*

#Copy default Apache2 conf
COPY 000-default.conf /etc/apache2/sites-available/000-default.conf

#Install GLPI on exec time and start app
ENTRYPOINT ["/opt/scripts/glpi-install-start.sh"]

#Exposition des ports
EXPOSE 443
