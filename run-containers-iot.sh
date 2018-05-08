#!/bin/bash

# Before running this, edit the value below and login to the openshift regustry
# docker login -u openshift -p (OPENSHIFT TOKEN, run on your openshift: oc whoami -t) https://$REGISTRY_ADDR

REGISTRY_ADDR=registry-default.apps.52.179.125.95.nip.io

# end of configuration



docker pull $REGISTRY_ADDR/iot-development/businessrules:latest
docker pull $REGISTRY_ADDR/iot-development/software-sensor:latest
docker pull $REGISTRY_ADDR/iot-development/routingservice:latest
docker pull jboss-amq-6/amq63-openshift:latest


docker run -d --restart always --name amq63 -e AMQ_USER=admin -e AMQ_PASSWORD=change12_me -e AMQ_TRANSPORTS="openwire, mqtt" -e AMQ_QUEUES=message.to.rules -e AMQ_SPLIT=true -e AMQ_MESH_DISCOVERY_TYPE=dns -e AMQ_MESH_SERVICE_NAME=broker-amq-mesh -e AMQ_MESH_SERVICE_NAMESPACE=default -e AMQ_STORAGE_USAGE_LIMIT="1 gb" jboss-amq-6/amq63-openshift:latest

docker run -d --restart always --link amq63:amq63 --name routingservice -e SOURCE_AMQ_BROKER=tcp://amq63:61616 -e SOURCE_BROKER_ADMIN_UID=admin -e SOURCE_BROKER_ADMIN_PASSWD=change12_me -e BROKER_AMQ_MQTT_HOST=amq63 $REGISTRY_ADDR/iot-development/routingservice:latest

docker run -d --restart always --link amq63:amq63 --name businessrules -e JAVA_APP_JAR=rules-jar-with-dependencies.jar -e SOURCE_AMQ_BROKER=tcp://amq63:61616 -e SOURCE_QUEUE=message.to.rules -e SOURCE_BROKER_ADMIN_UID=admin -e SOURCE_BROKER_ADMIN_PASSWD=change12_me -e TARGET_AMQ_BROKER=tcp://172.16.0.5:30616 -e TARGET_QUEUE=message.to.datacenter -e TARGET_BROKER_ADMIN_UID=admin -e TARGET_BROKER_ADMIN_PASSWD=change12_me $REGISTRY_ADDR/iot-development/businessrules:latest

docker run -d --restart always --link amq63:amq63 --name software-sensor -e JAVA_OPTIONS="-DhighWater=800 -DlowWater=200 -DbrokerUID=admin -DbrokerPassword=change12_me -DreceiverURL=amq63 -DdeviceType=temperature -DdeviceID=4711 -DinitialValue=70 -Dcount=1000 -DwaitTime=1" -e "JAVA_APP_JAR=softwareSensor-jar-with-dependencies.jar" $REGISTRY_ADDR/iot-development/software-sensor:latest


