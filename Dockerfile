FROM            centos:centos7

ARG VERSION=1.3.0

MAINTAINER      Siwei Wang <wangsiwei2003@hotmail.com>

ENV             DIST_MIRROR             http://mirror.cc.columbia.edu/pub/software/apache/nifi
ENV             NIFI_HOME               /opt/nifi

# Install necessary packages, create target directory, download and extract, and update the banner to let people know what version they are using
RUN             yum install -y java-1.8.0-openjdk tar net-tools && \
                mkdir -p /opt/nifi && \
                curl ${DIST_MIRROR}/${VERSION}/nifi-${VERSION}-bin.tar.gz | tar xvz -C ${NIFI_HOME} --strip-components=1 && \
                sed -i -e "s|^nifi.ui.banner.text=.*$|nifi.ui.banner.text=Docker NiFi ${VERSION}|" ${NIFI_HOME}/conf/nifi.properties && \
                groupadd nifi && \
                useradd -r -g nifi nifi && \
                bash -c "mkdir -p ${NIFI_HOME}/{database_repository,flowfile_repository,content_repository,provenance_repository}" && \
                chown nifi:nifi -R ${NIFI_HOME}

# Add start up script
ADD             ./sh/ /opt/sh
RUN             chmod 755 /opt/sh/start.sh

# Expose web port
EXPOSE          8080 8443
VOLUME          ["/opt/certs", "${NIFI_HOME}/flowfile_repository", "${NIFI_HOME}/database_repository", "${NIFI_HOME}/content_repository", "${NIFI_HOME}/provenance_repository"]

# Run as unprivileged user
USER nifi
WORKDIR ${NIFI_HOME}

CMD             ["/opt/sh/start.sh"]
