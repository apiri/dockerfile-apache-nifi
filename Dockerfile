FROM            centos:centos7

MAINTAINER      Aldrin Piri <aldrinpiri@gmail.com>

RUN             yum install -y java-1.7.0-openjdk-devel
ADD             nifi-*-bin.tar.gz       /opt/
RUN             mv /opt/*               /opt/nifi

# Expose web port 
EXPOSE         443 

ADD             ./sh/ /opt/sh
WORKDIR         /opt/nifi/
CMD             ["/opt/sh/start.sh"]
