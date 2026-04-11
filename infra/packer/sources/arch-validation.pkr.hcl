source "proxmox-clone" "arch_validation" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify

  node       = var.proxmox_node
  clone_vm   = var.gold_template_arch
  full_clone = var.validation_template_full_clone

  os              = "l26"
  bios            = "seabios"
  machine         = "pc"
  cpu_type        = var.validation_template_cpu_type
  scsi_controller = "virtio-scsi-single"

  vm_id   = var.validation_template_vm_id_arch
  vm_name = "${var.validation_template_name_prefix}-arch-validation-build"

  template_name        = "${var.validation_template_name_prefix}-arch-validation-template"
  template_description = "Dotfiles Arch validation template cloned from ${var.gold_template_arch}."
  tags                 = "dotfiles;validation-template;arch"

  cores   = var.validation_template_cores
  sockets = 1
  memory  = var.validation_template_memory_mb

  network_adapters {
    bridge = var.vm_bridge
    model  = "virtio"
  }

  ipconfig {
    ip      = var.validation_template_ip_arch
    gateway = var.validation_template_gateway_ipv4
  }

  rng0 {
    source    = "/dev/urandom"
    max_bytes = 1024
    period    = 1000
  }

  cloud_init              = true
  cloud_init_storage_pool = var.template_storage_pool
  cloud_init_disk_type    = "ide"

  ssh_host             = split("/", var.validation_template_ip_arch)[0]
  ssh_username         = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = var.ssh_timeout
}
