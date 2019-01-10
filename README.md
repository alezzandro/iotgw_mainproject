# Hybrid Deployments to the EDGE powered by Red Hat Openshift & Red Hat Enterprise Linux

This is the main project for the IoT Solution Demo: "<b>Hybrid Deployments to the EDGE powered by Red Hat Openshift & Red Hat Enterprise Linux</b>".

## Disclaimer and Thanks
This solution is made on top of "IoT Summit Lab 2016" -> https://github.com/redhat-iot/Virtual_IoT_Gateway

We've taken this demo, originally built as standalone applications to run on a virtual machine or remote raspberry pi device, and we ported it to Openshift, making its middleware apps working on containers.
So please look at the original Github repositories in the contributor tab for code's credits!

I would like also to thank [Andrea Tarocchi](https://github.com/valdar) and [Luca Bigotta](https://twitter.com/lucabigotta) who helped me in fighting with JBoss Fuse (I'm an infrastructure guy, sorry) and with the demo architecture, respectively.

The main objective of this demo is to show how Red Hat Openshift Container Platform may help you building your applications that you'll run on the "edge" smart gateways.
The applications developed with Openshift are by default portable thanks to Containers technology, we then added some bit of Ansible thanks to the Openshift Service Catalog and Ansible Service Broker and we'll monitor the deployments through Cockpit, the RHEL's integrated web interface.

The architecture to which we'll refer during this demo is the following:
![Architecture](/images/arch.png)

As you can see we have a Datacenter, in which we develops our applications thanks to a Virtualization Layer (Red Hat Virtualization) and a PaaS (Openshift Container Platform).
The apps will flow from Datacenter to the Hub and Smart Gateways thanks to this flow:
![Development Flow](/images/development.png)


You'll find all the different application projects used in this demo below:
- [Software_Sensor](https://github.com/alezzandro/iotgw_Software_Sensor)
- [Routing_Service](https://github.com/alezzandro/iotgw_Routing_Service)
- [BusinessRules_Service](https://github.com/alezzandro/iotgw_BusinessRules_Service)

## Prerequisites

First of all you'll need:
- a working Openshift Container Platform 3.11 with exposed registry ([look here for documentation](https://docs.openshift.com/container-platform/3.11/install_config/registry/securing_and_exposing_registry.html)) If you're using Minishift or CDK: please take a look to Minishift Addons and Minishift Components for enabling Exposed Registry and Ansible Service Broker.
- an empty RHEL7 properly configured (see below for the steps)

All the brand new installation should come with a pre-configured Ansible Service Broker and Openshift Service Catalog.
<i>You'll not get it enabled in Minishift or CDK, please refer to their docs for instruction on enabling it.</i>

As said, you'll need an empty RHEL7 configured with the following steps:
```
# yum remove -y firewalld
# yum install -y iptables-services podman cockpit
# systemctl enable cockpit iptables
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
# iptables -F
# iptables-save > /etc/sysconfig/iptables
```


## Openshift Setup Steps

You can run the following commands for creating the base environment on Openshift side:
```
# git clone https://github.com/alezzandro/iotgw_mainproject
# oc new-project iot-development
# oc process -f project-iot-development.yaml | oc create -f -
# oc new-project iot-testing
# oc process -f project-iot-testing.yaml | oc create -f -
# oc new-project iot-hub
# oc process -f project-iot-hub.yaml | oc create -f -
```

These commands will configure three Openshit's project:
- Development project with all the tools and pipeline for promoting containers in the Testing environment
- One dedicated for Testing, no building elements here, it receives updated containers from Dev env.
- A project dedicated to simulate the Hub Datacenter that usually is placed in the Factory.

After that we need to give to Jenkins' Service Account of the iot-development project the right of managing resources in the iot-testing project:
```
# oc policy add-role-to-user edit system:serviceaccount:iot-development:jenkins -n iot-testing
```

## Ansible Playbook Bundle Setup

We can now setup the Ansible Playbook Bundle, first of all we need to generate a SSH key that will be bundled in the APB:
```
# cd iotgw_mainproject/deploy-containers-apb
# ssh-keygen -f ./id_rsa
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in ./id_rsa.
Your public key has been saved in ./id_rsa.pub.
The key fingerprint is:
SHA256:3fBEgjbjMZh1+W2lkaDQSdqYpwwKecxbpUQ/yLbTBJk alex@lenny
The key's randomart image is:
+---[RSA 2048]----+
|     .+*+++oo. . |
|   + oE*BB++  o .|
|  o + BoB==... + |
|   o = *.= =. +  |
|    o o S . o.   |
|       .         |
|                 |
|                 |
|                 |
+----[SHA256]-----+

# ls id_rsa*
id_rsa  id_rsa.pub

# cat id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1JONXBS1XQpx7fwU8ttL311/XhFO9l8qOWrPIw3D14Y/ZCgMUkzfnySCR+gSs9pmI+8mO3SizJ0bnwkCrd8y+BlSuVSIGN37cLKc04YMwFhk5aQRpvigaIIyHEp2eakUEEdE2qLs1WoYhRputVxLGsWqzdhdv6vX7CDncgcRDVmdxGANXBdcfn6H7CFYw9f5PP6GVsTQBO4negowBp6q6fN+o3/eoo03BwFBub7J6sWXPOb9txiE6yOMs4+h3SvcTYkPyxEoBPcCkwyb/MhvjTvJl3SDvE1IbcUrruBVfvkfEOQ9mRKj7ZEtrJIS4gwLEOodRMaHRhI2nG5F1wSO1 alex@lenny
```

After that we have to take the token for the default Service Account created in each project, named "builder" and paste it inside our Playbook:
```
# oc project iot-testing
Now using project "iot-testing" on server "https://masterdnst75****"

# oc get sa
NAME       SECRETS   AGE
builder    2         21h
default    2         21h
deployer   2         21h

# oc describe sa builder
Name:                builder
Namespace:           iot-testing
Labels:              <none>
Annotations:         <none>
Image pull secrets:  builder-dockercfg-65wnj
Mountable secrets:   builder-token-7dppk
                     builder-dockercfg-65wnj
Tokens:              builder-token-7dppk
                     builder-token-8t6mn
Events:              <none>

# oc get secret builder-token-7dppk -o yaml | grep token: | awk '{print $2;}' | base64 -d
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJpb3QtdGVzdGluZyIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJidWlsZGVyLXRva2VuLTdkcHBrIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImJ1aWxkZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiI5YjUxYzViOC02MzU4LTExZTgtYmM1OS0wMDBkM2ExYTY2NDIiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6aW90LXRlc3Rpbmc6YnVpbGRlciJ9.i5iR6OenEMRD7qj0WBzLdHTlJ2rzlD5vmrLY-suZssCMKviuMtmIvrzt0ZY8coq_1EGZvvmtVEvqzosVNz_DA4MoURutOgVekqjj6dFUz-GlJ4ig_T01FIj1-pdfVVuZQD9fU-Id9a1UQZkegucrUoJwy1XRuAFufyIAAqQLvj6QwHEIX7ANKfi4xf7-PVJ2BhwFByeWm4WdY75YRU7Copj0ps8ieCT4UMN_vJWoC4m5dHFTAhuM5e8c_Bwx-yJP5dAkHV7rgKxTz1g07OPldFdlG-TE-TkFiXkiVN-_-q6Yhr9-xj_
```
We need this token because the Openshift Registry is secured and it needs a valid account for pulling down container images.
Now we got the Service Account token, we can place in the Playbook that we'll use for pulling Openshift images on the remote RHEL:
```
# vi deploy-containers-apb/playbooks/provision.yaml
...
- name: Starting containers provisioning on remote RHEL
  hosts: target_group
  remote_user: root
  gather_facts: false
  vars:
    token: "YOUR_TOKEN_HERE"
    registryaddr: "YOUR_OCP_ADDRESS_HERE"
...
        TARGET_AMQ_BROKER: tcp://YOUR_INFRA_ADDR:30616
...
```
As you see by the previous file, you need to replace the token value, the registry address and the address of one of your infrastructure node (we configured a NodePort for the iot-hub's AMQ container).

Finally we can start the build of the Ansible Playbook Bundle and proceed with the upload to the Openshift Registry.
I suggest you to use a machine of the cluster, for example one of the masters.
First of all we need to login with an administrative user other than system:admin, this is necessary due the needs of a token, so for this demo purposes I've created an user "ocpadmin" with role "ClusterAdmin":
```
# oc whoami
ocpadmin

# oc project openshift
```
Then we can go forward with the APB process:
```
# yum install -y apb

# cd iotgw_mainproject/deploy-containers-apb/

# apb prepare
Wrote b64 encoded [apb.yml] to [Dockerfile]

Create a buildconfig:
oc new-build --binary=true --name <bundle-name>

Start a build:
oc start-build --follow --from-dir . <bundle-name>

# oc start-build --follow --from-dir . deploy-containers-apb
Uploading directory "." as binary input for the build ...

Uploading finished
build.build.openshift.io/deploy-containers-apb-11 started
Receiving source from STDIN as archive ...
Step 1/10 : FROM ansibleplaybookbundle/apb-base
 ---> 1f7ea01fe3a0
Step 2/10 : LABEL "com.redhat.apb.spec" "dmVyc2lvbjogMS4wCm5hbWU6IGRlcGxveS1jb250YWluZXJzLWFwYgpkZXNjcmlwdGlvbjogVGhpcyBpcyBhIHNhbXBsZSBBUEIgYXBwbGljYXRpb24gdGhhdCBkZXBsb3lzIGNvbnRhaW5lcnMgb24gcmVtb3RlIGhvc3QKYmluZGFibGU6IEZhbHNlCmFzeW5jOiBvcHRpb25hbAptZXRhZGF0YToKICBkaXNwbGF5TmFtZTogSW9UIFJlbW90ZSBDb250YWluZXIgRGVwbG95ZXIgLSBUZXN0aW5nCiAgaW1hZ2VVcmw6IGh0dHBzOi8vZDMweTljZHN1N3hsZzAuY2xvdWRmcm9udC5uZXQvcG5nLzM1ODc1MS0yMDAucG5nCnBsYW5zOgogIC0gbmFtZTogZGVmYXVsdAogICAgZGVzY3JpcHRpb246IFRoaXMgZGVmYXVsdCBwbGFuIGRlcGxveXMgZGVwbG95LWNvbnRhaW5lcnMtYXBiCiAgICBmcmVlOiBUcnVlCiAgICBtZXRhZGF0YToge30KICAgIHBhcmFtZXRlcnM6IAogICAgICAtIG5hbWU6IHRhcmdldF9ob3N0IAogICAgICAgIHRpdGxlOiBUYXJnZXQgSG9zdCBmb3IgY29udGFpbmVycyBwcm92aXNpb25pbmcKICAgICAgICB0eXBlOiBzdHJpbmcKICAgICAgICBkZWZhdWx0OiAxNzIuMTYuMC43CiAgICAgICAgcmVxdWlyZWQ6IHRydWUK"
 ---> Using cache
 ---> ef715be4bd28
Step 3/10 : COPY playbooks /opt/apb/actions
 ---> 16631bd52abf
Removing intermediate container f7fe5f13f67d
Step 4/10 : COPY roles /opt/ansible/roles
 ---> b68e59ef6ba4
Removing intermediate container b1c222a54b6e
Step 5/10 : COPY id_rsa /opt/apb/
 ---> 62f475cd6409
Removing intermediate container 82b0090b6062
Step 6/10 : RUN echo "host_key_checking = False" >> /opt/apb/ansible.cfg
 ---> Running in ec8a37a9eaf8
 ---> f93a61b66b4d
Removing intermediate container ec8a37a9eaf8
Step 7/10 : RUN chmod -R g=u /opt/{ansible,apb}
 ---> Running in 0d85f781c415
 ---> 27fe0b8791f0
Removing intermediate container 0d85f781c415
Step 8/10 : USER apb
 ---> Running in 5c1db3469a45
 ---> dea4bdfd0386
Removing intermediate container 5c1db3469a45
Step 9/10 : ENV "OPENSHIFT_BUILD_NAME" "deploy-containers-apb-11" "OPENSHIFT_BUILD_NAMESPACE" "openshift"
 ---> Running in c246fbb533ae
 ---> d746e5826ba1
Removing intermediate container c246fbb533ae
Step 10/10 : LABEL "io.openshift.build.name" "deploy-containers-apb-11" "io.openshift.build.namespace" "openshift"
 ---> Running in a961a25cb9b0
 ---> 140f3c2e482c
Removing intermediate container a961a25cb9b0
Successfully built 140f3c2e482c
Pushing image 172.30.1.1:5000/openshift/deploy-containers-apb:latest ...
Pushed 0/17 layers, 0% complete
Pushed 1/17 layers, 29% complete
Pushed 2/17 layers, 29% complete
Pushed 3/17 layers, 29% complete
Pushed 4/17 layers, 29% complete
Pushed 5/17 layers, 29% complete
Pushed 6/17 layers, 35% complete
Pushed 7/17 layers, 41% complete
Pushed 8/17 layers, 47% complete
Pushed 9/17 layers, 53% complete
Pushed 10/17 layers, 59% complete
Pushed 11/17 layers, 65% complete
Pushed 12/17 layers, 71% complete
Pushed 13/17 layers, 76% complete
Pushed 14/17 layers, 82% complete
Pushed 15/17 layers, 88% complete
Pushed 16/17 layers, 94% complete
Pushed 17/17 layers, 100% complete
Push successful
```

We should see the just uploaded APB in the Service Catalog, as soon as we refresh the Openshift Service Catalog page, as shown in the image below:
![Ansible Playbook Bundle](/images/apb.png)

Are you further interested in the Ansible Playbook Bundle and Openshift Service Catalog?
Take a look at one of article I wrote on Red Hat Developer Blog: [Customizing an OpenShift Ansible Playbook Bundle](https://developers.redhat.com/blog/2018/05/23/customizing-an-openshift-ansible-playbook-bundle/)

We can now take the public key and deploy it on our Smart Gateway RHEL7 based:
```
[root@smartgw ~]$ mkdir -p .ssh
[root@smartgw ~]$ echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1JONXBS1XQpx7fwU8ttL311/XhFO9l8qOWrPIw3D14Y/ZCgMUkzfnySCR+gSs9pmI+8mO3SizJ0bnwkCrd8y+BlSuVSIGN37cLKc04YMwFhk5aQRpvigaIIyHEp2eakUEEdE2qLs1WoYhRputVxLGsWqzdhdv6vX7CDncgcRDVmdxGANXBdcfn6H7CFYw9f5PP6GVsTQBO4negowBp6q6fN+o3/eoo03BwFBub7J6sWXPOb9txiE6yOMs4+h3SvcTYkPyxEoBPcCkwyb/MhvjTvJl3SDvE1IbcUrruBVfvkfEOQ9mRKj7ZEtrJIS4gwLEOodRMaHRhI2nG5F1wSO1 root@rhel" >> ,ssh/authorized_keys
[root@smartgw ~]$ chmod 700 .ssh
[root@smartgw ~]$ chmod 600 .ssh/authorized_keys
```
Please note, we assume that we will connect to the remote host as root user, please test that the SSH key login is working before proceeding to the APB deployment.

## That's all!
You now have an Openshift environment with all the necessary for showing the demo, consisting in:
1. Development environment with Jenkins' pipelines and three components:
   - Software-Sensor: that will simulate a temperature Sensor
   - Routing_Service: handling the communication and messages dispatching between different AMQ queues
   - BusinessRules_Service: that will filter the data coming from the Sensor, deciding when trigger an alarm (that will be a message on a dedicated queue)
2. Testing environment without Build components, that let you test the software and spawn the containers on a remote RHEL (via APB)
   - This is the right place where to execute the Ansible Playbook Bundle and trigger the remote deployments
3. Hub environment, that simulates the Factory's datacenter, containing for demo purposes only an AMQ container, handling just one queue where you receive the sensor alarm.
   - This is the backend for the containers you will deploy on the remote RHEL7
