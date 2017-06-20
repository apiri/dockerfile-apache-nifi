#!/bin/bash

# NIFI_HOME is defined by an ENV command in the backing Dockerfile
nifi_props_file=${NIFI_HOME}/conf/nifi.properties
bootstrap_file=${NIFI_HOME}/conf/bootstrap.conf
logback_file=${NIFI_HOME}/conf/logback.xml
state_management_file=${NIFI_HOME}/conf/state-management.xml
jaas_config_file=${NIFI_HOME}/conf/zookeeper-jaas.conf
krb_config_file=${NIFI_HOME}/conf/krb.conf
authorizers_config_file=${NIFI_HOME}/conf/authorizers.xml
login_identity_providers_config_file=${NIFI_HOME}/conf/login-identity-providers.xml
hr() {
    width=20
    if [[ -s "$TERM" ]]
    then
        width=$(tput cols)
    fi
    printf '\n%*s\n\n' "${COLUMNS:-${width}}" '' | tr ' ' '*'
}

update_jvm_size() {
    echo Configuring jvm heap
    if [[ -z ${JVM_HEAP_START+x} ]]; then
        echo "JVM start heapsize is not specified, Using default value"
    else
        echo "JVM start heapsize is set to ${JVM_HEAP_START}"
        sed -i "s|^java.arg.2=.*$|java.arg.2=${JVM_HEAP_START}|" ${bootstrap_file}
    fi

    if [[ -z ${JVM_HEAP_MAX+x} ]]; then
        echo "JVM max heapsize is not specified, Using default value"
    else
        echo "JVM max heapsize is set to ${JVM_HEAP_MAX}"
        sed -i "s|^java.arg.3=.*$|java.arg.3=${JVM_HEAP_MAX}|" ${bootstrap_file}
    fi
}

update_repository_archive() {
     echo Configuring repository archive settings
     if [[ -z ${ARCHIVE_ENABLED+x} ]]; then
        echo "nifi content repository archive enabled not specified, Using default value (true)"
    else
        echo "nifi content repository archive enabled is set to ${ARCHIVE_ENABLED}"
        sed -i "s|^nifi.content.repository.archive.enabled=.*$|nifi.content.repository.archive.enabled=${ARCHIVE_ENABLED}|" ${nifi_props_file}
    fi
}

update_provenance_repository() {
     echo Configuring provenance repository settings
     if [[ -z ${REPOSITORY_INDEX_THREADS+x} ]]; then
        echo "nifi provenance repository index threads not specified, Using default value 1"
    else
        echo "nifi provenance repository index threads is set to ${REPOSITORY_INDEX_THREADS}"
        sed -i "s|^nifi.provenance.repository.index.threads=.*$|nifi.provenance.repository.index.threads=${REPOSITORY_INDEX_THREADS}|" ${nifi_props_file}
    fi
}

enable_ssl() {
    echo Configuring environment with SSL settings
    : ${KEYSTORE_PATH:?"Must specify an absolute path to the keystore being used."}
    if [[ ! -f "${KEYSTORE_PATH}" ]]; then
        echo "Keystore file specified (${KEYSTORE_PATH}) does not exist."
        exit 1
    fi
    : ${KEYSTORE_TYPE:?"Must specify the type of keystore (JKS, PKCS12, PEM) of the keystore being used."}
    : ${KEYSTORE_PASSWORD:?"Must specify the password of the keystore being used."}

    : ${TRUSTSTORE_PATH:?"Must specify an absolute path to the truststore  being used."}
    if [[ ! -f "${TRUSTSTORE_PATH}" ]]; then
        echo "Keystore file specified (${TRUSTSTORE_PATH}) does not exist."
        exit 1
    fi
    : ${TRUSTSTORE_TYPE:?"Need to set DEST non-empty"}
    : ${TRUSTSTORE_PASSWORD:?"Need to set DEST non-empty"}

    sed -i "s|^nifi.security.keystore=.*$|nifi.security.keystore=${KEYSTORE_PATH}|" ${nifi_props_file}
    sed -i "s|^nifi.security.keystoreType=.*$|nifi.security.keystoreType=${KEYSTORE_TYPE}|" ${nifi_props_file}
    sed -i "s|^nifi.security.keystorePasswd=.*$|nifi.security.keystorePasswd=${KEYSTORE_PASSWORD}|" ${nifi_props_file}
    sed -i "s|^nifi.security.truststore=.*$|nifi.security.truststore=${TRUSTSTORE_PATH}|" ${nifi_props_file}
    sed -i "s|^nifi.security.truststoreType=.*$|nifi.security.truststoreType=${TRUSTSTORE_TYPE}|" ${nifi_props_file}
    sed -i "s|^nifi.security.truststorePasswd=.*$|nifi.security.truststorePasswd=${TRUSTSTORE_PASSWORD}|" ${nifi_props_file}

    # Disable HTTP and enable HTTPS
    sed -i -e 's|nifi.web.http.port=.*$|nifi.web.http.port=|' ${nifi_props_file}
    sed -i -e 's|nifi.web.https.port=.*$|nifi.web.https.port=8443|' ${nifi_props_file}

    # Enable secure remote input
    sed -i 's|nifi.remote.input.secure=.*$|nifi.remote.input.secure=true|' ${nifi_props_file}

    # TODO: Bind to all interface
    echo "" >>  ${nifi_props_file}
    echo "nifi.web.https.network.interface.eth0=eth0" >> ${nifi_props_file}
    echo "nifi.web.https.network.interface.eth1=eth1" >> ${nifi_props_file}

    # Enable ssl for cluster
    sed -i 's|nifi.cluster.protocol.is.secure=.*$|nifi.cluster.protocol.is.secure=true|' ${nifi_props_file}

    # Add node identity to the authorizers file
    if [[ -z ${NIFI_NODE_IDENTITY_LIST+x} ]]; then
        echo "nifi node identity list not specified"
    else
        echo "nifi node identity list is set to ${NIFI_NODE_IDENTITY_LIST}"
        IFS=';' read -ra nodes <<< "${NIFI_NODE_IDENTITY_LIST}"
        for i in "${!nodes[@]}"
        do
            sed -i "/<property name=\"Legacy Authorized Users File\"><\/property>/a \ \ \ \ \ \ \ \ <property name=\"Node Identity $((i+1))\">${nodes[$i]}<\/property>" ${authorizers_config_file}
        done
    fi
}

disable_ssl() {
    echo Configuring environment with default HTTP settings

    sed -i -e 's|^nifi.security.keystore=.*$|nifi.security.keystore=|' ${nifi_props_file}
    sed -i -e 's|^nifi.security.keystoreType=.*$|nifi.security.keystoreType=|' ${nifi_props_file}
    sed -i -e 's|^nifi.security.keystorePasswd=.*$|nifi.security.keystorePasswd=|' ${nifi_props_file}
    sed -i -e 's|^nifi.security.truststore=.*$|nifi.security.truststore=|' ${nifi_props_file}
    sed -i -e 's|^nifi.security.truststoreType=.*$|nifi.security.truststoreType=|' ${nifi_props_file}
    sed -i -e 's|^nifi.security.truststorePasswd=.*$|nifi.security.truststorePasswd=|' ${nifi_props_file}

    # Disable HTTPS and enable HTTP
    sed -i -e 's|^nifi.web.http.port=.*$|nifi.web.http.port=8080|' ${nifi_props_file}
    sed -i -e 's|^nifi.web.https.port=.*$|nifi.web.https.port=|' ${nifi_props_file}

    # Disable secure remote input
    sed -i 's|nifi.remote.input.secure=.*$|nifi.remote.input.secure=|' ${nifi_props_file}

    # TODO Bind to all interface
    echo "" >>  ${nifi_props_file}
    echo "nifi.web.http.network.interface.eth0=eth0" >> ${nifi_props_file}
    echo "nifi.web.http.network.interface.eth1=eth1" >> ${nifi_props_file}

    # Disable ssl for cluster
    sed -i 's|nifi.cluster.protocol.is.secure=.*$|nifi.cluster.protocol.is.secure=false|' ${nifi_props_file}
}

update_logging_level() {
    # only support the top level logging which is org.apache.nifi
    echo Configuring logging levels
    if [[ -z ${NIFI_LOGGING_LEVEL+x} ]]; then
        echo "nifi logging level is not specified, Using default value (INFO)"
    else
        echo "nifi logging level is set to ${NIFI_LOGGING_LEVEL}"
        sed -i "s|name=\"org.apache.nifi\" level=\"INFO\"|name=\"org.apache.nifi\" level=\"${NIFI_LOGGING_LEVEL}\"|" ${logback_file}
    fi
}

update_host() {
    echo Configuring host
    if [[ -z ${NIFI_HOST+x} ]]; then
        echo "nifi host is not specified, Using default value (localhost)"
    else
        echo "nifi host name is set to ${NIFI_HOST}"
        sed -i "s|nifi.remote.input.host=.*$|nifi.remote.input.host=${NIFI_HOST}|" ${nifi_props_file}
        sed -i "s|nifi.web.http.host=.*$|nifi.web.http.host=${NIFI_HOST}|" ${nifi_props_file}
        sed -i "s|nifi.web.https.host=.*$|nifi.web.https.host=${NIFI_HOST}|" ${nifi_props_file}
    fi
}

configure_cluster() {
    echo Configuring cluster
    if [[ -z ${NIFI_CLUSTER_IS_NODE+x} ]]; then
        echo "nifi cluster is node is not specified, Using default value (false). Nifi is running in standalone mode."
        # Since it is not cluster mode, do not need to consume other variables that are cluster specific
        # exit the function without terminate the script
        return 0
    else
        echo "nifi cluster is node is set to ${NIFI_CLUSTER_IS_NODE}, Nifi is running in cluster mode"
        sed -i "s|nifi.cluster.is.node=.*$|nifi.cluster.is.node=${NIFI_CLUSTER_IS_NODE}|" ${nifi_props_file}
    fi

    if [[ -z ${NIFI_CLUSTER_NODE_ADDRESS+x} ]]; then
        echo "NIFI_CLUSTER_NODE_ADDRESS is not specified but required in the cluster mode."
        exit 1
    else
        echo "nifi cluster node address is set to ${NIFI_CLUSTER_NODE_ADDRESS}"
        sed -i "s|nifi.cluster.node.address=.*$|nifi.cluster.node.address=${NIFI_CLUSTER_NODE_ADDRESS}|" ${nifi_props_file}
    fi

    if [[ -z ${NIFI_CLUSTER_NODE_PROTOCOL_PORT+x} ]]; then
        echo "NIFI_CLUSTER_NODE_PROTOCOL_PORT is not specified but required in the cluster mode."
        exit 1
    else
        echo "nifi cluster node protocol port is set to ${NIFI_CLUSTER_NODE_PROTOCOL_PORT}"
        sed -i "s|nifi.cluster.node.protocol.port=.*$|nifi.cluster.node.protocol.port=${NIFI_CLUSTER_NODE_PROTOCOL_PORT}|" ${nifi_props_file}
    fi

    if [[ -z ${NIFI_ZOOKEEPER_CONNECT_STRING+x} ]]; then
        echo "nifi zookeeper connect string is not specified but required in the cluster mode."
        exit 1
    else
        echo "nifi zookeeper connect string  is set to ${NIFI_ZOOKEEPER_CONNECT_STRING}"
        sed -i "s|<property name=\"Connect String\"></property>|<property name=\"Connect String\">${NIFI_ZOOKEEPER_CONNECT_STRING}</property>|" ${state_management_file}
        sed -i "s|nifi.zookeeper.connect.string=.*$|nifi.zookeeper.connect.string=${NIFI_ZOOKEEPER_CONNECT_STRING}|" ${nifi_props_file}
    fi

    if [[ -z ${NIFI_CLUSTER_FLOW_ELECTION_MAX_TIME+x} ]]; then
        echo "nifi flow election max wait time is not specified, using default value (5 minutes)."
    else
        echo "nifi flow election max wait time is set to ${NIFI_CLUSTER_FLOW_ELECTION_MAX_TIME}"
        sed -i "s|nifi.cluster.flow.election.max.wait.time=.*$|nifi.cluster.flow.election.max.wait.time=${NIFI_CLUSTER_FLOW_ELECTION_MAX_TIME}|" ${nifi_props_file}
    fi

    if [[ -z ${NIFI_REMOTE_INPUT_SOCKET_PORT+x} ]]; then
        echo "nifi remote input socket port is not specified, using default value (empty) and S2S function is disabled."
    else
        echo "nifi remote input port is set to ${NIFI_REMOTE_INPUT_SOCKET_PORT}"
        sed -i "s|nifi.remote.input.socket.port=.*$|nifi.remote.input.socket.port=${NIFI_REMOTE_INPUT_SOCKET_PORT}|" ${nifi_props_file}
    fi

}

configure_kerberos(){
    echo "configure kerberos setting for Kafka"

cat << EOT > ${jaas_config_file}
Client {
  com.sun.security.auth.module.Krb5LoginModule required
  useKeyTab=true
  keyTab=""
  useTicketCache=false
  principal="";
};
KafkaClient {
   com.sun.security.auth.module.Krb5LoginModule required
   useTicketCache=false
   renewTicket=true
   serviceName="kafka"
   useKeyTab=true
   keyTab=""
   principal="";
};
EOT

cat << EOT > ${krb_config_file}
[logging]
 default = FILE:/var/log/kerberos/krb5libs.log
 kdc = FILE:/var/log/kerberos/krb5kdc.log
 admin_server = FILE:/var/log/kerberos/kadmind.log

[libdefaults]
 default_realm = DEFAULT_REALM
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true

[realms]
 DEFAULT_REALM = {
  kdc = KDC_SERVER
  admin_server = KDC_SERVER
 }

[domain_realm]
 .DEFAULT_REALM = DEFAULT_REALM
 DEFAULT_REALM = DEFAULT_REALM
EOT

    if [[ -z ${NIFI_KEYTAB_PATH+x} ]]; then
        echo "nifi keytab file path is not specified but required when kerberos is enabled."
        exit 1
    else
        echo "nifi keytab file path is set to ${NIFI_KEYTAB_PATH}"
        sed -i "s|keyTab=.*$|keyTab=\"${NIFI_KEYTAB_PATH}\"|g" ${jaas_config_file}
    fi

    if [[ -z ${NIFI_KEYTAB_PRINCIPAL+x} ]]; then
        echo "nifi keytab principal is not specified but required when kerberos is enabled."
        exit 1
    else
        echo "nifi keytab principal is  set to ${NIFI_KEYTAB_PRINCIPAL}"
        sed -i "s|principal=.*$|principal=\"${NIFI_KEYTAB_PRINCIPAL}\";|g" ${jaas_config_file}
    fi

    if [[ -z ${NIFI_KERBEROS_DEFAULT_REALM+x} ]]; then
        echo "nifi kerberos realm is not specified but required when kerberos is enabled."
        exit 1
    else
        echo "nifi kerberos realm is set to ${NIFI_KERBEROS_DEFAULT_REALM}"
        sed -i "s|DEFAULT_REALM|${NIFI_KERBEROS_DEFAULT_REALM}|g" ${krb_config_file}
    fi

    if [[ -z ${NIFI_KERBEROS_KDC_SERVER+x} ]]; then
        echo "nifi kerberos kdc server is not specified but required when kerberos is enabled."
        exit 1
    else
        echo "nifi kerberos kdc server is set to ${NIFI_KERBEROS_KDC_SERVER}"
        sed -i "s|KDC_SERVER|${NIFI_KERBEROS_KDC_SERVER}|g" ${krb_config_file}
    fi

    # set JAAS configuration for kerberos
    cat << EOT >> ${bootstrap_file}
#set JAAS configuration for kerberos
java.arg.15=-Djava.security.auth.login.config=${jaas_config_file}
java.arg.16=-Djava.security.krb5.conf=${krb_config_file}
EOT

}

configure_LDAP() {
    sed -i "s|nifi.security.user.login.identity.provider=.*$|nifi.security.user.login.identity.provider=ldap-provider|g" ${nifi_props_file}
    sed -i "s|<property name=\"Initial Admin Identity\"></property>|<property name=\"Initial Admin Identity\">${NIFI_LDAP_INIT_ADMIN}</property>|" ${authorizers_config_file}

cat << EOT > ${login_identity_providers_config_file}
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<loginIdentityProviders>
<provider>
    <identifier>ldap-provider</identifier>
    <class>org.apache.nifi.ldap.LdapProvider</class>
    <property name="Authentication Strategy">SIMPLE</property>

    <property name="Manager DN"></property>
    <property name="Manager Password"></property>
    <property name="TLS - Keystore"></property>
    <property name="TLS - Keystore Password"></property>
    <property name="TLS - Keystore Type"></property>
    <property name="TLS - Truststore"></property>
    <property name="TLS - Truststore Password"></property>
    <property name="TLS - Truststore Type"></property>
    <property name="TLS - Client Auth"></property>
    <property name="TLS - Protocol"></property>
    <property name="TLS - Shutdown Gracefully"></property>
    <property name="Referral Strategy">FOLLOW</property>
    <property name="Connect Timeout">10 secs</property>
    <property name="Read Timeout">10 secs</property>

    <property name="Url"></property>
    <property name="User Search Base"></property>
    <property name="User Search Filter"></property>
    <property name="Authentication Expiration">12 hours</property>
</provider>
</loginIdentityProviders>
EOT

    if [[ -z ${NIFI_LDAP_MANAGER_DN+x} ]]; then
        echo "nifi ldap manager dn is not specified but required when ldap is enabled."
        exit 1
    else
        echo "nifi ldap manager dn is set to ${NIFI_LDAP_MANAGER_DN}"
        sed -i "s|<property name=\"Manager DN\"></property>|<property name=\"Manager DN\">${NIFI_LDAP_MANAGER_DN}</property>|g" ${login_identity_providers_config_file}
    fi

    if [[ -z ${NIFI_LDAP_MANAGER_PASSWORD+x} ]]; then
        echo "nifi ldap manager password not specified but required when ldap is enabled."
        exit 1
    else
        echo "nifi ldap manager password is set to ************"
        sed -i "s|<property name=\"Manager Password\"></property>|<property name=\"Manager Password\">${NIFI_LDAP_MANAGER_PASSWORD}</property>|g" ${login_identity_providers_config_file}
    fi

    if [[ -z ${NIFI_LDAP_URL+x} ]]; then
        echo "nifi ldap url not specified but required when ldap is enabled."
        exit 1
    else
        echo "nifi ldap url password is set to ${NIFI_LDAP_URL}"
        sed -i "s|<property name=\"Url\"></property>|<property name=\"Url\">${NIFI_LDAP_URL}</property>|g" ${login_identity_providers_config_file}
    fi

    if [[ -z ${NIFI_LDAP_USER_SEARCH_BASE+x} ]]; then
        echo "nifi ldap user search base not specified but required when ldap is enabled."
        exit 1
    else
        echo "nifi ldap user search base is set to ${NIFI_LDAP_USER_SEARCH_BASE}"
        sed -i "s|<property name=\"User Search Base\"></property>|<property name=\"User Search Base\">${NIFI_LDAP_USER_SEARCH_BASE}</property>|g" ${login_identity_providers_config_file}
    fi

    if [[ -z ${NIFI_LDAP_USER_SEARCH_FILTER+x} ]]; then
        echo "nifi ldap user search filter not specified but required when ldap is enabled."
        exit 1
    else
        echo "nifi ldap user search filter is set to ${NIFI_LDAP_USER_SEARCH_FILTER}"
        sed -i "s|<property name=\"User Search Filter\"></property>|<property name=\"User Search Filter\">${NIFI_LDAP_USER_SEARCH_FILTER}</property>|g" ${login_identity_providers_config_file}
    fi
}

update_jvm_size

update_repository_archive

update_logging_level

update_host

configure_cluster

if [[ "$DISABLE_SSL" != "true" ]]; then
    enable_ssl
else
    hr
    echo 'NOTE: Apache NiFi has not been configured to run with SSL and is open to anyone that has access to the exposed UI port on which it runs.  Please safeguard accordingly.'
    hr
    disable_ssl
fi

if [[ "$DISABLE_KERBEROS" != "true" ]]; then
    configure_kerberos
else
    hr
    echo 'NOTE: Apache NiFi has not been configured to run with kerberos.'
    hr
fi

if [[ "$DISABLE_LDAP" != "true" ]]; then
    configure_LDAP
else
    hr
    echo 'NOTE: Apache NiFi has not been configured to run with LDAP.'
    hr
fi

# Continuously provide logs so that 'docker logs' can produce them
tail -F ${NIFI_HOME}/logs/nifi-app.log &
${NIFI_HOME}/bin/nifi.sh run
