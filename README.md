# Hybrid Deployments to the EDGE powered by Red Hat Openshift & Red Hat Enterprise Linux

This is the main project for the IoT Solution Demo: "<b>Hybrid Deployments to the EDGE powered by Red Hat Openshift & Red Hat Enterprise Linux</b>".

This solution is made on top of "IoT Summit Lab 2016" -> https://github.com/redhat-iot/Virtual_IoT_Gateway

We've taken this demo, originally built as standalone applications to run on a virtual machine or remote raspberry pi device, and we ported it to Openshift, making its middleware apps working on containers.
The main objective of this demo is to show how Red Hat Openshift Container Platform may help you building your applications that you'll run on the "edge" smart gateways.
The applications developed with Openshift are by default portable thanks to Containers technology, we then added some bit of Ansible thanks to the Openshift Service Catalog and Ansible Service Broker and we'll monitor the deployments through Cockpit, the RHEL's integrated web interface.

The architecture to which we'll refer during this demo is the following:
![Architecture](/images/arch.png)

As you can see we have a Datacenter, in which we develops our applications thanks to a Virtualization Layer (Red Hat Virtualization) and a PaaS (Openshift Container Platform).
The apps will flow from Datacenter to the Hub and Smart Gateways thanks to this flow:
![Development Flow](/images/development.png)


## Prerequisites

First of all you'll need a working Openshift Container Platform 3.9.
All the brand new installation should come with a pre-configured Ansible Service Broker and Openshift Service Catalog.
<i>You'll not get it enabled in Minishift or CDK, please refer to their docs for instruction on enabling it.</i>

Then you'll need an empty RHEL7 configured with the following steps:
```
# yum remove firewalld
# yum install -y iptables-services docker docker-python cockpit
# systemctl enable cockpit docker iptables
```

Before starting the needed services you have to add your Openshift externally exposed registry into '/etc/containers/registries.conf':
```
# cat /etc/containers/registries.conf

# This is a system-wide configuration file used to
# keep track of registries for various container backends.
# It adheres to TOML format and does not support recursive
# lists of registries.

# The default location for this configuration file is /etc/containers/registries.conf.

# The only valid categories are: 'registries.search', 'registries.insecure',
# and 'registries.block'.

[registries.search]
registries = ['registry.access.redhat.com']

# If you need to access insecure registries, add the registry's fully-qualified name.
# An insecure registry is one that does not have a valid SSL certificate or only does HTTP.
[registries.insecure]
registries = ['registry-default.apps.52.179.125.95.nip.io']


# If you need to block pull access from a registry, uncomment the section below
# and add the registries fully-qualified name.
#
# Docker only
[registries.block]
registries = []
```

Then you can start the services:
```
# systemctl start iptables cockpit docker
```


## Setup Steps

You can run the following commands for creating the base environment on Openshift side:
```
# git clone https://github.com/alezzandro/iotgw_mainproject
# oc new-project iot-development
# oc create -f project-iot-development.yaml
# oc new-project iot-testing
# oc create -f project-iot-testing.yaml
# oc new-project iot-hub
# oc create -f project-iot-hub.yaml
```

These commands will configure three Openshit's project:
- Development project with all the tools and pipeline for promoting containers in the Testing environment
- One dedicated for Testing, no building elements here, it receives updated containers from Dev env.
- A project dedicated to simulating the Hub Datacenter that usually is placed in the Factory.
