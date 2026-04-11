build {
  name    = "debian-14-validation-template"
  sources = ["source.proxmox-clone.debian_14_validation"]

  provisioner "shell" {
    environment_vars = [
      "PACKER_SSH_USERNAME=${var.ssh_username}",
    ]
    execute_command = "chmod +x '{{ .Path }}' && sudo -E bash '{{ .Path }}'"
    script          = "./scripts/bootstrap-debian-validation.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "PACKER_SSH_USERNAME=${var.ssh_username}",
    ]
    execute_command = "chmod +x '{{ .Path }}' && sudo -E bash '{{ .Path }}'"
    script          = "./scripts/finalize-template-common.sh"
  }
}

build {
  name    = "arch-validation-template"
  sources = ["source.proxmox-clone.arch_validation"]

  provisioner "shell" {
    environment_vars = [
      "PACKER_SSH_USERNAME=${var.ssh_username}",
    ]
    execute_command = "chmod +x '{{ .Path }}' && sudo -E bash '{{ .Path }}'"
    script          = "./scripts/bootstrap-arch-validation.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "PACKER_SSH_USERNAME=${var.ssh_username}",
    ]
    execute_command = "chmod +x '{{ .Path }}' && sudo -E bash '{{ .Path }}'"
    script          = "./scripts/finalize-template-common.sh"
  }
}
