#!/bin/bash

# NIFI_HOME is defined by an ENV command in the backing Dockerfile
nifi_props_file=${NIFI_HOME}/conf/nifi.properties
bootstrap_file=${NIFI_HOME}/conf/bootstrap.conf
logback_file=${NIFI_HOME}/conf/logback.xml
state_management_file=${NIFI_HOME}/conf/state-management.xml
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

    sed -i '\|^nifi.security.keystore=| s|$|'${KEYSTORE_PATH}'|g' ${nifi_props_file}
    sed -i '\|^nifi.security.keystoreType=| s|$|'${KEYSTORE_TYPE}'|g' ${nifi_props_file}
    sed -i '\|^nifi.security.keystorePasswd=| s|$|'${KEYSTORE_PASSWORD}'|g' ${nifi_props_file}
    sed -i '\|^nifi.security.truststore=| s|$|'${TRUSTSTORE_PATH}'|g' ${nifi_props_file}
    sed -i '\|^nifi.security.truststoreType=| s|$|'${TRUSTSTORE_TYPE}'|g' ${nifi_props_file}
    sed -i '\|^nifi.security.truststorePasswd=| s|$|'${TRUSTSTORE_PASSWORD}'|g' ${nifi_props_file}

    # Disable HTTP and enable HTTPS
    sed -i -e 's|nifi.web.http.port=.*$|nifi.web.http.port=|' ${nifi_props_file}
    sed -i -e 's|nifi.web.https.port=.*$|nifi.web.https.port=8443|' ${nifi_props_file}
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
    sed -i -e 's|nifi.web.http.port=.*$|nifi.web.http.port=8080|' ${nifi_props_file}
    sed -i -e 's|nifi.web.https.port=.*$|nifi.web.https.port=|' ${nifi_props_file}
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
    echo Configuring cluster
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
        echo "nifi cluster node address is set to ${NIFI_CLUSTER_NODE_PROTOCOL_PORT}"
        sed -i "s|nifi.cluster.node.protocol.port=.*$|nifi.cluster.node.protocol.port=${NIFI_CLUSTER_NODE_PROTOCOL_PORT}|" ${nifi_props_file}
    fi

    if [[ -z ${NIFI_ZOOKEEPER_CONNECT_STRING+x} ]]; then
        echo "nifi zookeeper connect string is not specified but required in the cluster mode."
        exit 1
    else
        echo "nifi cluster node address is set to ${NIFI_ZOOKEEPER_CONNECT_STRING}"
        sed -i "s|<property name=\"Connect String\"></property>|<property name=\"Connect String\">${NIFI_ZOOKEEPER_CONNECT_STRING}</property>|" ${state_management_file}
        sed -i "s|nifi.zookeeper.connect.string=.*$|nifi.zookeeper.connect.string=${NIFI_ZOOKEEPER_CONNECT_STRING}|" ${nifi_props_file}
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


# Continuously provide logs so that 'docker logs' can produce them
tail -F ${NIFI_HOME}/logs/nifi-app.log &
${NIFI_HOME}/bin/nifi.sh run
