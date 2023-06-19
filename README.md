# Packer configuration files for OpenStack

Some configuration files for images, which might be useful for services on top of OpenStack

## Overview

 - consul.pkr.hcl - a simple Debian 11 image, that is patched in order to be provisionable with terraform provisioners using the root user. Don't forget to switch back to non-root after provisioning your instances.
 - postgresql14-patroni-consul.pkr.hcl - a Debian 11 image, which gets Consul, Postgres, Patroni, the Citus Postgres extension, pgbackrest, the Percona Monitoring and Management client as well as the Percona pg-stat-monitor Postgres extension installed
