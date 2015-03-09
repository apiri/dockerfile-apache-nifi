FROM            centos:centos7

MAINTAINER      Aldrin Piri

RUN             yum install -y java-1.7.0-openjdk-devel
ADD             nifi-*-bin.tar.gz       /opt/

# Expose web port 
EXPOSE          8080

WORKDIR         /opt/nifi-0.0.1-incubating/
CMD             ["bin/nifi.sh", "run"]
