variable "image_version" {
  type = string
  default = "${env("TF_VAR_dd_image_name")}" 
}

variable "flavor" {
  type = string
  default = "SCS-2V:2:20"
}

locals {
    consul_version="1.15.2"
    timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

packer {
  required_plugins {
    openstack = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

source "openstack" "postgresql14-patroni-consul" {
  image_name    = "postgresql14-patroni-consul"
  flavor        = "${var.flavor}"
  cloud = "prod3"
  instance_name = "image_builder_${uuidv4()}"
  networks      = ["12e2fa99-0511-42b3-975a-8c1710b7d772"]
  floating_ip_pool = "ext01"
  use_floating_ip = true
  security_groups = [ "default" ]
  communicator  = "ssh"
  ssh_username  = "root"
  ssh_pty       = "true"
  source_image_filter {
     filters {
        name = "debian-11-consul" 
     }
     most_recent = "true"
  }
}

build {
  sources = ["source.openstack.postgresql14-patroni-consul"]

  provisioner "file" {
    source = "${path.root}/files/consul.service"
    destination = "/etc/systemd/system/consul.service" 
  }

  provisioner "file" {
    source = "${path.root}/files/patroni.service"
    destination = "/etc/systemd/system/patroni.service"
  }

  provisioner "file" {
    source = "${path.root}/files/pgdg.list"
    destination = "/etc/apt/sources.list.d/pgdg.list"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get -y install wget unzip gnupg",
      "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -",
      
      "sudo apt-get update",

      "sudo mkdir -p /etc/consul/certificates",
      "sudo mkdir -p /opt/consul",
      "sudo useradd -d /opt/consul consul",
      "sudo chown consul /opt/consul",
      "sudo chgrp consul /opt/consul",

      "cd /tmp ; wget --no-check-certificate https://releases.hashicorp.com/consul/${local.consul_version}/consul_${local.consul_version}_linux_amd64.zip",
      "cd /tmp ; unzip consul_${local.consul_version}_linux_amd64.zip",
      "cd /tmp ; rm consul_${local.consul_version}_linux_amd64.zip",

      "mv /tmp/consul /usr/local/bin/consul",

      "sudo apt-get update",
      "sudo apt-get -y install postgresql-14",
      "sudo apt-get -y install postgresql-contrib",
      "sudo systemctl disable postgresql.service",
      
      # PIP
      "sudo apt-get -y install python3-pip",
      "sudo apt-get -y install python3-psycopg2",

      # Patroni
      "pip3 install patroni[consul]",

      # Build and install citus extension
      "curl https://install.citusdata.com/community/deb.sh | sudo bash",
      "sudo apt-get -y install postgresql-14-citus-11.3",
      "sudo pg_conftool 14 main set shared_preload_libraries citus",


      # Build and install pgbackrest
      "sudo apt-get -y install pgbackrest",

      # Install pmm-client
      "cd /tmp ; wget --no-check-certificate https://downloads.percona.com/downloads/pmm2/2.37.0/binary/debian/bullseye/x86_64/pmm2-client_2.37.0-6.bullseye_amd64.deb",
      "dpkg -i /tmp/pmm2-client_2.37.0-6.bullseye_amd64.deb",
      "cd /tmp ; rm pmm2-client*.deb",

      # Install percona-release
      "cd /tmp ; curl -O https://repo.percona.com/apt/percona-release_latest.generic_all.deb",
      "cd /tmp ; sudo apt-get -y install gnupg2 lsb-release ./percona-release_latest.generic_all.deb",
      "sudo apt update",
      "sudo percona-release setup ppg14",
      "sudo apt-get -y install percona-pg-stat-monitor14",
      "cd /tmp ; rm percona-release_latest.generic_all.deb",
    ]
  }

  provisioner "file" {
    source = "${path.root}/postgresql14-patroni/patroni.yml"
    destination = "/var/lib/postgresql/patroni.yml"
  }
}
