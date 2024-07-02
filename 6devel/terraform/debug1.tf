locals {
  main = {
    "0" = {
      "addresses" = toset([
        "10.4.24.138",
      ])
      "id" = "infra-k8s-master-1-t1-migrate-1159.terra.inno.tech."
      "name" = "infra-k8s-master-1-t1-migrate-1159"
      "ttl" = 3600
      "zone" = "terra.inno.tech."
    }
    "1" = {
      "addresses" = toset([
        "10.4.24.139",
      ])
      "id" = "infra-k8s-worker-1-t1-migrate-1159.terra.inno.tech."
      "name" = "infra-k8s-worker-1-t1-migrate-1159"
      "ttl" = 3600
      "zone" = "terra.inno.tech."
    }
  }
}
output "main" {
  value = [for v in local.main: "${trim(v.id, ".")} (${tolist(v.addresses)[0]})"]
}

