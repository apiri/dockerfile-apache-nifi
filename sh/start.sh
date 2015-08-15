#!/bin/bash

# NIFI_HOME is defined by an ENV command in the backing Dockerfile
nifi_props_file=${NIFI_HOME}/conf/nifi.properties

hr() {
    width=20
    if [[ -s "$TERM" ]]
    then
        width=$(tput cols)
    fi
    printf '\n%*s\n\n' "${COLUMNS:-${width}}" '' | tr ' ' '*'
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
    sed -i -e 's|nifi.web.https.port=.*$|nifi.web.https.port=443|' ${nifi_props_file}
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
    sed -i -e 's|nifi.web.http.port=.*$|nifi.web.http.port=80|' ${nifi_props_file}
    sed -i -e 's|nifi.web.https.port=.*$|nifi.web.https.port=|' ${nifi_props_file}
}

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
