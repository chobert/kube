terraform {
  backend "remote" {
    organization = "chobert"

    workspaces {
      name = "kube"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.31.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }

    remote = {
      source  = "tenstad/remote"
      version = ">= 0.0.23"
    }
  }
}
