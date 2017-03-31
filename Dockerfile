FROM            centos:centos7

MAINTAINER      Aldrin Piri <aldrinpiri@gmail.com>

ENV             DIST_MIRROR             http://mirror.cc.columbia.edu/pub/software/apache/nifi
ENV             NIFI_HOME               /opt/nifi
ENV             VERSION                 1.1.2

# Install necessary packages, create target directory, download and extract, and update the banner to let people know what version they are using
RUN             yum install -y java-1.8.0-openjdk tar && \
                mkdir -p /opt/nifi && \
                curl ${DIST_MIRROR}/${VERSION}/nifi-${VERSION}-bin.tar.gz | tar xvz -C ${NIFI_HOME} --strip-components=1 && \
                sed -i -e "s|^nifi.ui.banner.text=.*$|nifi.ui.banner.text=Docker NiFi ${VERSION}|" ${NIFI_HOME}/conf/nifi.properties && \
                groupadd nifi && \
                useradd -r -g nifi nifi && \
                bash -c "mkdir -p ${NIFI_HOME}/{database_repository,flowfile_repository,content_repository,provenance_repository}" && \
                chown nifi:nifi -R ${NIFI_HOME} \
                timedatectl set-timezone America/Toronto

# Expose web port
EXPOSE          8080 8443
VOLUME          ["/opt/certs", "${NIFI_HOME}/flowfile_repository", "${NIFI_HOME}/database_repository", "${NIFI_HOME}/content_repository", "${NIFI_HOME}/provenance_repository"]

# Run as unprivileged user
USER nifi
WORKDIR ${NIFI_HOME}

ADD             ./sh/ /opt/sh
CMD             ["/opt/sh/start.sh"]
