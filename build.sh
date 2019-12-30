#!/bin/bash
#VAULT_VERSION=`curl https://releases.hashicorp.com/vault/ -q 2>&1 | egrep -o "_[0-9\.]+" | sed 's/_//' | sort -r | head -n 1` && curl https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip --output vault.zip -q && unzip -f vault.zip; rm -f vault.zip
docker build --compress --force-rm --no-cache -t duplicity:`date +%Y-%m-%d` -t duplicity:latest .
