FROM            centos:centos7

MAINTAINER      Aldrin Piri <aldrinpiri@gmail.com>

ENV             NIFI_HOME               /opt/nifi

RUN             yum install -y java-1.7.0-openjdk-devel
ADD             nifi-*-bin.tar.gz       /opt/
RUN             mv /opt/*               ${NIFI_HOME}


# Expose web port 
EXPOSE          443 
VOLUME          ["/opt/certs", "${NIFI_HOME}/flowfile_repository", "${NIFI_HOME}/content_repository", "${NIFI_HOME}/database_repository", "${NIFI_HOME}/content_repository", "${NIFI_HOME}/provenance_repository"]

ADD             ./sh/ /opt/sh
CMD             ["/opt/sh/start.sh"]
