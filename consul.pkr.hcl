packer {
  required_plugins {
    openstack = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

variable "image_version" {
  type    = string
  default = "${env("TF_VAR_dd_image_name")}" 
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") } 

source "openstack" "debian-11-consul" {
  image_name    = "debian-11-consul"
  flavor = "SCS-2V:2:20"
  ssh_username = "debian"
  cloud = "patroni"
  instance_name = "image_builder_${uuidv4()}"
  networks         = [ "53a878f2-306e-45db-a523-904b05c2e208" ]
  floating_ip_pool = "ext01"
  use_floating_ip  = true
  security_groups  = [ "default" ]
  communicator = "ssh" 
  ssh_pty = "true"
  source_image_filter {
     filters { 
       name = "Debian 11"
     }
     most_recent = "true"
  }
}

build {
  sources = ["source.openstack.debian-11-consul"]

  provisioner "file" {
    source = "${path.root}/patches/sshd_config.patch"
    destination = "/var/tmp/sshd_config.patch"
  }

  provisioner "file" {
    source = "${path.root}/patches/cloud.cfg.patch"
    destination = "/var/tmp/cloud.cfg.patch"
  }

  provisioner "file" {
   source = "${path.root}/files/10-consul.dnsmasq"
   destination = "/var/tmp/10-consul"
  }

  provisioner "file" {
   source = "${path.root}/files/dnsmasq.conf"
   destination = "/var/tmp/dnsmasq.conf"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y patch",
      "sudo apt-get install -y unzip",
      "sudo patch /etc/ssh/sshd_config < /var/tmp/sshd_config.patch",
      "sudo systemctl restart sshd",
      "sudo patch /etc/cloud/cloud.cfg < /var/tmp/cloud.cfg.patch",
      "sudo apt-get install -y dnsmasq",
      "sudo cp /var/tmp/dnsmasq.conf /etc/dnsmasq.conf",
      "sudo cp /var/tmp/10-consul /etc/dnsmasq.d/10-consul",
      "sudo systemctl disable systemd-resolved",
      "sudo systemctl stop systemd-resolved",
      "sudo systemctl enable dnsmasq",
      "sudo systemctl start dnsmasq",
      "sudo systemctl daemon-reload",
    ]
  }
}
