variable "location" {
  default = "nbg1"
}

variable "instances_count" {
  default = 3
}

variable "hcloud_token" {
  sensitive = true
}
