terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
}

resource "digitalocean_tag" "web" {
  name = "Jenkins"
}

resource "digitalocean_droplet" "jenkins" {
  image  = "ubuntu-20-04-x64"
  name   = "web-1"
  region = "nyc3"
  size   = "s-2vcpu-4gb"
  ssh_keys = [
    "7f:4c:49:3b:4d:1e:ba:14:da:0b:ed:87:b0:1a:00:e0"
  ]

  connection {
    user = "root"
    type = "ssh"
    host = self.ipv4_address
    private_key = file("~/.ssh/id_ed25519")
  }

  tags = [
    digitalocean_tag.web.id
  ]

  provisioner "file" {
    source      = "ansible/jenkins_setup.yml"
    destination = "/home/jenkins_setup.yml"
  }

  provisioner "file" {
    source      = "plugins.txt"
    destination = "/home/plugins.txt"
  }

  provisioner "file" {
    source      = "jcasc.yaml"
    destination = "/home/jcasc.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "until cloud-init status --wait; do echo 'Waiting for cloud-init...'; sleep 5; done",
      "sudo apt update",
      "sudo apt install software-properties-common -y",
      "sudo apt-add-repository --yes --update ppa:ansible/ansible",
      "sudo apt install ansible -y",
      "ansible --version",
      "ansible-playbook --version",
      "export ANSIBLE_HOST_KEY_CHECKING=False",
      "ansible-playbook /home/jenkins_setup.yml"
    ]
    
  }
}

resource "digitalocean_firewall" "jenkins_sg" {
  name = "jenkins-sg"
  droplet_ids = [
    digitalocean_droplet.jenkins.id
  ]

  inbound_rule {
    protocol           = "tcp"
    port_range         = "22"
    source_addresses   = [ "0.0.0.0/0" ]
  }

  inbound_rule {
    protocol           = "tcp"
    port_range         = "8080-8083"
    source_addresses   = [ "0.0.0.0/0" ]
  }

  inbound_rule {
    protocol           = "tcp"
    port_range         = "9000"
    source_addresses   = [ "0.0.0.0/0" ]
  }

  outbound_rule {
    protocol           = "tcp"
    port_range         = "0"
    destination_addresses = [ "0.0.0.0/0" ]
  }
}