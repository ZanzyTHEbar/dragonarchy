variable "proxmox_url" {
  type        = string
  description = "Proxmox API endpoint, including /api2/json."
}

variable "proxmox_username" {
  type        = string
  description = "Proxmox username, including realm and token id when using API tokens."
}

variable "proxmox_token" {
  type        = string
  description = "Proxmox API token secret."
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name to run the build on."
}

variable "proxmox_insecure_skip_tls_verify" {
  type        = bool
  description = "Skip TLS verification for the Proxmox API."
  default     = true
}

variable "vm_bridge" {
  type        = string
  description = "Proxmox bridge for template networking."
  default     = "vmbr0"
}

variable "template_storage_pool" {
  type        = string
  description = "Storage pool for the template disk and cloud-init disk."
  default     = "local-lvm"
}

variable "ssh_username" {
  type        = string
  description = "Guest SSH username baked into templates via cloud-init."
  default     = "dragon"
}

variable "ssh_private_key_file" {
  type        = string
  description = "Private key used by Packer to SSH into build guests."
}

variable "ssh_timeout" {
  type        = string
  description = "SSH timeout for Packer communicator."
  default     = "30m"
}

variable "validation_template_name_prefix" {
  type        = string
  description = "Prefix for generated validation template names."
  default     = "dotfiles"
}

variable "validation_template_cores" {
  type        = number
  description = "vCPU count for validation templates."
  default     = 2
}

variable "validation_template_memory_mb" {
  type        = number
  description = "RAM size in MiB for validation templates."
  default     = 4096
}

variable "graphical_validation_template_cores" {
  type        = number
  description = "vCPU count for desktop-class graphical validation templates."
  default     = 4
}

variable "graphical_validation_template_memory_mb" {
  type        = number
  description = "RAM size in MiB for desktop-class graphical validation templates."
  default     = 8192
}

variable "validation_template_cpu_type" {
  type        = string
  description = "CPU type exposed to validation templates."
  default     = "host"
}

variable "validation_template_full_clone" {
  type        = bool
  description = "Whether Packer should use a full clone from the gold template."
  default     = true
}

variable "validation_template_gateway_ipv4" {
  type        = string
  description = "IPv4 gateway used by static validation-template build VMs."
  default     = "192.168.0.1"
}

variable "validation_template_ip_debian_14" {
  type        = string
  description = "Static IPv4/CIDR for the Debian validation-template build VM."
  default     = "192.168.0.253/24"
}

variable "validation_template_ip_arch" {
  type        = string
  description = "Static IPv4/CIDR for the Arch validation-template build VM."
  default     = "192.168.0.254/24"
}

variable "validation_template_ip_arch_graphical" {
  type        = string
  description = "Static IPv4/CIDR for the Arch graphical validation-template build VM."
  default     = "192.168.0.252/24"
}

variable "gold_template_debian_14" {
  type        = string
  description = "Gold Debian 14 cloud-base template name."
  default     = "debian-14-cloud-base"
}

variable "gold_template_arch" {
  type        = string
  description = "Gold Arch Linux cloud-base template name."
  default     = "arch-cloud-base"
}

variable "validation_template_vm_id_debian_14" {
  type        = number
  description = "Cluster-unique VMID for the Debian validation template artifact."
  default     = 9310
}

variable "validation_template_vm_id_arch" {
  type        = number
  description = "Cluster-unique VMID for the Arch validation template artifact."
  default     = 9320
}

variable "validation_template_vm_id_arch_graphical" {
  type        = number
  description = "Cluster-unique VMID for the Arch graphical validation template artifact."
  default     = 9330
}
