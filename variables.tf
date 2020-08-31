# hetzner server
variable "hcloud_token" {}
variable "ssh_private_key" {
  type = string
  default = "~/.ssh/id_rsa"
}
variable "ssh_keys" {
  type = list
  default = []
}

# k3s config
variable "k3os_install" {}
variable "k3os_iso" {}
variable "k3s_token" {}
variable "k3s_ssh_authorized_keys" {}
variable "k3s_agent_count" {
  type = number
  default = 1
}
