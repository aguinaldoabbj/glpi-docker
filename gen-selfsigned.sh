#!/bin/bash

openssl req -x509 -nodes -days 7300 -subj "${ORG_PARAMS}" -addext "subjectAltName=DNS:mydomain.com" -newkey rsa:2048 -keyout /etc/ssl/private/selfsigned.key -out /etc/ssl/certs/selfsigned.crt