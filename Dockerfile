FROM ubuntu:20.04
WORKDIR /opt/duplicity 
ENV FULL_BACKUP_INTERVAL=8D FULL_RETENTION_INTERVAL=3M INCR_RETENTION_FULL=5
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install duplicity -y && rm -rf /var/lib/apt /var/cache
COPY *.sh ./
COPY --from=vault:latest /bin/vault /bin 
RUN chmod +x ./init.sh ./duplicity.sh /bin/vault
RUN ./init.sh
