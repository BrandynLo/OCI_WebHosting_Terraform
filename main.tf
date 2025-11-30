terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 7.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}

provider "oci" {
  region              = "us-ashburn-1"
  auth                = "APIKey"
  config_file_profile = "default"
}

variable "compartment_id" {
  type        = string
  description = "OCID of your compartment"
}

variable "vm_count" {
  type    = number
  default = 1
}

variable "vm_names" {
  type    = list(string)
  default = ["vm-1", "vm-2", "vm-3"]
}

# Get availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

locals {
  ad_name = data.oci_identity_availability_domains.ads.availability_domains[0].name
}

# Ubuntu 22.04 – Free AMD shape
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# VCN + Internet Gateway + Route Table
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_block     = "172.16.0.0/20"
  display_name   = "main-vcn"
  dns_label      = "main"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "igw"
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "public-rt"
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Security List
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "public-sl"

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }
  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
    }
  }
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

# Public subnet
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "172.16.1.0/24"
  display_name               = "public-subnet"
  dns_label                  = "public"
  availability_domain        = local.ad_name
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  dhcp_options_id            = oci_core_vcn.main.default_dhcp_options_id
}

# Instances
resource "oci_core_instance" "vms" {
  for_each = toset([for i in range(var.vm_count) : tostring(i)])

  availability_domain = local.ad_name
  compartment_id      = var.compartment_id
  shape               = "VM.Standard2.1"

  lifecycle {
    create_before_destroy = true
  }

  display_name = length(var.vm_names) > tonumber(each.key) ? var.vm_names[tonumber(each.key)] : "vm-${tonumber(each.key) + 1}"

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = file("~/.ssh/my_oci_key.pub")
    user_data           = base64encode(templatefile("${path.module}/user_data.sh.tpl", {}))
  }
}

# Ansible caller
resource "null_resource" "run_ansible" {
  for_each = oci_core_instance.vms

  triggers = {
    instance_id       = each.value.id
    playbook_checksum = filemd5("${path.module}/playbook.yml")
  }

  provisioner "local-exec" {
    environment = {
      PYTHONUNBUFFERED        = "1"
      ANSIBLE_STDOUT_CALLBACK = "debug"
    }

    command = <<-EOT
      #!/usr/bin/env bash
      set -euo pipefail
      IP="${each.value.public_ip}"
      echo "Quick-waiting for SSH on $IP..."
      until ssh -i ~/.ssh/my_oci_key -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 ubuntu@$IP true 2>/dev/null; do sleep 5; done
      echo "SSH ready – running Ansible immediately..."
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "$IP," --user ubuntu --private-key ~/.ssh/my_oci_key playbook.yml
      echo "DONE → http://$IP"
    EOT

    interpreter = ["bash", "-c"]
    working_dir = path.module
  }

  depends_on = [oci_core_instance.vms]
}

# Outputs
output "ssh_commands" {
  value = { for vm in oci_core_instance.vms : vm.display_name => "ssh -i ~/.ssh/my_oci_key ubuntu@${vm.public_ip}" }
}

output "website_urls" {
  value = { for vm in oci_core_instance.vms : vm.display_name => "http://${vm.public_ip}" }
}
