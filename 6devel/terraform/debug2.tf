variable "vms" {
  type = list(object({
    vm_name        = string
    vm_ip          = string
    ansible_groups = list(string)
  }))
  default = [
    {
      vm_name        = "master"
      vm_ip          = "1.1.1.1"
      ansible_groups = ["master", "node"]
    },
    {
      vm_name        = "ingress1"
      vm_ip          = "1.1.1.2"
      ansible_groups = ["ingress", "node"]
    },
    {
      vm_name        = "ingress2"
      vm_ip          = "1.1.1.3"
      ansible_groups = ["ingress", "node"]
    },
    {
      vm_name        = "worker"
      vm_ip          = "1.1.1.4"
      ansible_groups = ["node"]
    }
  ]
}

output "main" {
  value = [for vm in var.vms : vm.vm_ip if contains(vm.ansible_groups, "ingress")]
}
