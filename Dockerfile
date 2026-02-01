# Dev By Hieu
FROM ubuntu:20.04

RUN apt-get update && \
    apt-get install -y shellinabox systemd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN echo 'root:hieudz999' | chpasswd

# set hostname
RUN echo "Hieu-VPS" > /etc/hostname && \
    echo "127.0.0.1 Hieu-VPS" >> /etc/hosts

EXPOSE 4200

CMD ["/usr/bin/shellinaboxd", "-t", "-s", "/:LOGIN"]
