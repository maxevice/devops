terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.0"
    }
  }
}

# Підключення до локального гіпервізора KVM
provider "libvirt" {
  uri = "qemu:///system"
}

# Завантажуємо офіційний образ Ubuntu (qcow2)
resource "libvirt_volume" "ubuntu_image" {
  name   = "ubuntu-jammy-base.qcow2"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

# Створюємо диск для Worker
resource "libvirt_volume" "worker_disk" {
  name           = "worker-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_image.id
  size           = 10737418240 # 10 ГБ
}

# Створюємо диск для БД
resource "libvirt_volume" "db_disk" {
  name           = "db-disk.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.ubuntu_image.id
  size           = 10737418240 # 10 ГБ
}

# Передаємо cloud-init для Worker
resource "libvirt_cloudinit_disk" "cloudinit_worker" {
  name      = "cloudinit-worker.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/cloud_init_worker.yml", {
    ansible_ssh_key = file("../ansible_key.pub")
  })
}

# Передаємо cloud-init для DB
resource "libvirt_cloudinit_disk" "cloudinit_db" {
  name      = "cloudinit-db.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/cloud_init_db.yml", {
    ansible_ssh_key = file("../ansible_key.pub")
  })
}

# Віртуальна машина Worker
resource "libvirt_domain" "worker" {
  name   = "shareride-worker"
  memory = "1024"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.cloudinit_worker.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true # Terraform сам дочекається IP-адреси
  }

  disk {
    volume_id = libvirt_volume.worker_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

# Віртуальна машина Database
resource "libvirt_domain" "db" {
  name   = "shareride-db"
  memory = "1024"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.cloudinit_db.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.db_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

# Виведення результатів
output "worker_ip" {
  value = libvirt_domain.worker.network_interface[0].addresses[0]
}

output "db_ip" {
  value = libvirt_domain.db.network_interface[0].addresses[0]
}