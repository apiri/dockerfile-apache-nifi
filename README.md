![Apache NiFi logo](http://nifi.apache.org/images/niFi-logo-horizontal.png "Apache NiFi")
# dockerfile-apache-nifi
## Version 0.6.1

### Apache NiFi Dockerfile

Provides a Dockerfile and associated scripts for configuring an instance of [Apache NiFi](http://nifi.apache.org) to run with certificate authentication.  

## Sample Usage

From your checkout directory:
		
1. Build the image

        docker build -t apiri/apache-nifi .
		
2. Run the image 

		docker run -i -t --rm \
	   	 	-p 8443:443 \
	    	-v ${cert_path}:/opt/certs \
	    	-v $(readlink -f ./authorized-users.xml):/opt/nifi/conf/authorized-users.xml \
	    	-e KEYSTORE_PATH=/opt/certs/keystore.jks \
	    	-e KEYSTORE_TYPE=JKS \
	    	-e KEYSTORE_PASSWORD=password \
	    	-e TRUSTSTORE_PATH=/opt/certs/truststore.jks \
	    	-e TRUSTSTORE_PASSWORD=password \
	    	-e TRUSTSTORE_TYPE=JKS \
	    	apiri/apache-nifi


	`-p 8443:443`
	exposes the UI at port 8443 on the Docker host system

	`-v ${cert_path}:/opt/certs` 
	maps the 'cert_path' location on the host system to the container as the source of the relevant keystores

	`-i -t` Allocates a TTY and keeps STDIN open

	`-v $(readlink -f ./authorized-users.xml):/opt/nifi/conf/authorized-users.xml` Maps an authorized-users.xml into the container over the default one provided

3. Wait for the image to initalize

		2015-03-21 18:14:37,879 INFO [main] org.apache.nifi.web.server.JettyServer NiFi has started. The UI is available at the following URLs:
		2015-03-21 18:14:37,880 INFO [main] org.apache.nifi.web.server.JettyServer https://172.17.0.37:443/nifi
		2015-03-21 18:14:37,880 INFO [main] org.apache.nifi.web.server.JettyServer https://127.0.0.1:443/nifi
		2015-03-21 18:14:37,880 INFO [main] org.apache.nifi.NiFi Controller initialization took 4572051363 nanoseconds.
		
4. Access through your Docker host system
 	
		https://localhost:8443/nifi
		
5. Stopping
		
* From the terminal used to start the container above, perform a `Ctrl+C` to send the interrupt to the container.
* Alternatively, execute a docker command for the container via a `docker stop <container id>` or `docker kill <container id>`

		
## Conventions
### $NIFI_HOME
- The Dockerfile specifies an environment variable `NIFI_HOME` via the `ENV` command

### Volumes
- The following directories are exposed as volumes which may optionally be mounted to a specified location
	- `/opt/certs`
	- `${NIFI_HOME}/flowfile_repository`
	- `${NIFI_HOME}/content_repository`
	- `${NIFI_HOME}/database_repository`
	- `${NIFI_HOME}/provenance_repository`
