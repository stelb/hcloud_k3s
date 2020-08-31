# Configure the Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_network" "private10" {
  name = "k3s"
  ip_range = "10.0.0.0/8"
}
resource "hcloud_network_subnet" "k3snet" {
  network_id = hcloud_network.private10.id
  network_zone = "eu-central"
  type = "cloud"
  ip_range = "10.23.23.0/24"
}

resource "hcloud_server" "k3smaster" {
    backups      = false
    #datacenter   = "hel1-dc2"
    image        = "ubuntu-16.04"
    labels       = {}
    location     = "hel1"
    name         = "k3smaster"
    server_type  = "cx11"
    #iso          = "k3os-amd64_v0.11.0.iso"
    ssh_keys     = var.ssh_keys

    connection {
      #host        = hcloud_server.k3smaster.ipv4_address
      host        = self.ipv4_address
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_private_key)
    }

    provisioner "file" {
      content = yamlencode({
        "ssh_authorized_keys": var.k3s_ssh_authorized_keys,
        "hostname": self.name,
        "k3os": {"token": var.k3s_token, "k3s_args": "server"}
        })

      destination = "/tmp/config.yaml"
    }

    provisioner "remote-exec" {
      inline = ["curl -O ${var.k3os_install}",
                "apt-get -qq update",
                "apt-get -qq install -y parted exfat-utils dosfstools",
                "bash install.sh --takeover --config /tmp/config.yaml --no-format /dev/sda1 ${var.k3os_iso}",
                "shutdown -r"
                ]
    }
}

resource "hcloud_server_network" "k3sserver" {
  server_id = hcloud_server.k3smaster.id
  subnet_id = hcloud_network_subnet.k3snet.id
  ip = cidrhost(hcloud_network_subnet.k3snet.ip_range, 1)
}


resource "hcloud_server" "agent" {
  count = var.k3s_agent_count
  name = format("agent-%04d", count.index + 1)
  image = "ubuntu-16.04"
  labels = {}
  location = "hel1"
  server_type = "cx11"
  ssh_keys = var.ssh_keys

  connection {
    host = self.ipv4_address
    type = "ssh"
    user = "root"
    private_key = file(var.ssh_private_key)
  }

  provisioner "file" {
    content = yamlencode({
      "ssh_authorized_keys": var.k3s_ssh_authorized_keys,
      "hostname": self.name,
      "k3os": {
        "token": var.k3s_token,
        "k3s_args": "agent",
        #"server_url": "https://${cidrhost(hcloud_network_subnet.k3snet.ip_range, 1)}:6443"
        "server_url": "https://${hcloud_server.k3smaster.ipv4_address}:6443"
      }
    })
    destination = "/tmp/config.yaml"
  }

  provisioner "remote-exec" {
    inline = ["curl -O ${var.k3os_install}",
              "apt-get -qq update",
              "apt-get -qq install -y parted exfat-utils dosfstools",
              "bash install.sh --takeover --config /tmp/config.yaml --no-format /dev/sda1 ${var.k3os_iso}",
              "shutdown -r"
            ]
    }
}

resource "hcloud_server_network" "k3sagent" {
  server_id = element(hcloud_server.agent.*.id, count.index)
  subnet_id = hcloud_network_subnet.k3snet.id
  ip = cidrhost(hcloud_network_subnet.k3snet.ip_range, count.index+2)

  count = var.k3s_agent_count
}
