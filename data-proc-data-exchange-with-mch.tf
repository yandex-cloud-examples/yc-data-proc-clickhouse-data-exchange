# Infrastructure for the Yandex Cloud Managed Service for ClickHouse, Yandex Data Processing, and Object Storage
#
# RU: https://cloud.yandex.ru/docs/data-proc/tutorials/exchange-data-with-mch
# EN: https://cloud.yandex.com/en/docs/data-proc/tutorials/exchange-data-with-mch
#
# Set the configuration of the Managed Service for ClickHouse cluster, Yandex Data Processing cluster, and Object Storage

locals {
  # Specify the following settings:
  folder_id = "" # Your cloud folder ID, same as for provider
  input_bucket  = "" # Name of an Object Storage bucket for input files. Must be unique in the Cloud
  output_bucket = "" # Name of an Object Storage bucket for output files. Must be unique in the Cloud
  dp_ssh_key = "" # An absolute path to the SSH public key for the Yandex Data Processing cluster
  mch_password = "" # A user password for the ClickHouse cluster

  # The following settings are predefined. Change them only if necessary.
  network_name = "dataproc-ch-network" # Name of the network
  nat_name = "dataproc-nat" # Name of the NAT gateway
  subnet_name = "dataproc-ch-subnet-a" # Name of the subnet
  dp_sa_name = "dataproc-sa" # Name of the service account for DataProc
  os_sa_name = "sa-for-obj-storage" # Name of the service account for Object Storage creating
  dataproc_name = "dataproc-cluster" # Name of the Yandex Data Processing cluster
  mch_name = "mch-cluster" # Name of the Managed Service for ClickHouse cluster
  mch_db_name = "db1" # Name of the ClickHouse database
  mch_user_name = "user1" # Name of the ClickHouse admin user
}

resource "yandex_vpc_network" "dataproc_ch_network" {
  description = "Network for Yandex Data Processing and Managed Service for ClickHouse"
  name        = local.network_name
}

# NAT gateway for Yandex Data Processing
resource "yandex_vpc_gateway" "dataproc_nat" {
  name = local.nat_name
  shared_egress_gateway {}
}

# Route table for Yandex Data Processing
resource "yandex_vpc_route_table" "dataproc-rt" {
  network_id = yandex_vpc_network.dataproc_ch_network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.dataproc_nat.id
  }
}

resource "yandex_vpc_subnet" "dataproc_ch_subnet-a" {
  description    = "Subnet in the ru-central1-a availability zone for Yandex Data Processing and Managed Service for ClickHouse"
  name           = local.subnet_name
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.dataproc_ch_network.id
  v4_cidr_blocks = ["10.140.0.0/24"]
  route_table_id = yandex_vpc_route_table.dataproc-rt.id
}

resource "yandex_vpc_security_group" "dataproc-security-group" {
  description = "Security group for the Yandex Data Processing cluster"
  network_id  = yandex_vpc_network.dataproc_ch_network.id

  ingress {
    description       = "Allow any incoming traffic within the security group"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    description       = "Allow any outgoing traffic within the security group"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }

  egress {
    description    = "Allow connections to the HTTPS port from any IP address"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow access to NTP servers for time syncing"
    protocol       = "UDP"
    port           = 123
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow connections to the ClickHouse port from any IP address"
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "mch_security_group" {
  description = "Security group for the Managed Service for ClickHouse cluster"
  network_id  = yandex_vpc_network.dataproc_ch_network.id

  ingress {
    description    = "Allow SSL connections to the Managed Service for ClickHouse cluster with clickhouse-client"
    protocol       = "TCP"
    port           = 9440
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "Allow HTTPS connections to the Managed Service for ClickHouse cluster"
    protocol       = "TCP"
    port           = 8443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Allow outgoing connections to any required resource"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_iam_service_account" "dataproc-sa" {
  description = "Service account to manage the Yandex Data Processing cluster"
  name        = local.dp_sa_name
}

# Assign the dataproc.agent role to the Yandex Data Processing service account
resource "yandex_resourcemanager_folder_iam_binding" "dataproc-agent" {
  folder_id = local.folder_id
  role      = "dataproc.agent"
  members   = ["serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"]
}

# Assign the dataproc.provisioner role to the Yandex Data Processing service account
resource "yandex_resourcemanager_folder_iam_binding" "dataproc-provisioner" {
  folder_id = local.folder_id
  role      = "dataproc.provisioner"
  members   = ["serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"]
}

# Yandex Object Storage bucket

# Create a service account for Object Storage creation
resource "yandex_iam_service_account" "sa-for-obj-storage" {
  folder_id = local.folder_id
  name      = local.os_sa_name
}

# Grant the service account storage.admin role to manage buckets and grant bucket ACLs
resource "yandex_resourcemanager_folder_iam_binding" "s3-admin" {
  folder_id = local.folder_id
  role      = "storage.admin"
  members   = ["serviceAccount:${yandex_iam_service_account.sa-for-obj-storage.id}"]
}

resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  description        = "Static access key for Object Storage"
  service_account_id = yandex_iam_service_account.sa-for-obj-storage.id
}

# Use keys to create an input bucket and grant permission to the Yandex Data Processing service account to read from the bucket
resource "yandex_storage_bucket" "input-bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = local.input_bucket

  depends_on = [
    yandex_resourcemanager_folder_iam_binding.s3-admin
  ]

  grant {
    id          = yandex_iam_service_account.dataproc-sa.id
    type        = "CanonicalUser"
    permissions = ["READ"]
  }
}

# Use keys to create an output bucket and grant permission to the Yandex Data Processing service account to read from the bucket and write to it
resource "yandex_storage_bucket" "output-bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = local.output_bucket

  depends_on = [
    yandex_resourcemanager_folder_iam_binding.s3-admin
  ]

  grant {
    id          = yandex_iam_service_account.dataproc-sa.id
    type        = "CanonicalUser"
    permissions = ["READ", "WRITE"]
  }
}

resource "yandex_dataproc_cluster" "dataproc-cluster" {
  description        = "Yandex Data Processing cluster"
  environment        = "PRODUCTION"
  depends_on         = [yandex_resourcemanager_folder_iam_binding.dataproc-agent,yandex_resourcemanager_folder_iam_binding.dataproc-provisioner]
  bucket             = yandex_storage_bucket.output-bucket.id
  security_group_ids = [yandex_vpc_security_group.dataproc-security-group.id]
  name               = local.dataproc_name
  service_account_id = yandex_iam_service_account.dataproc-sa.id
  zone_id            = "ru-central1-a"
  ui_proxy           = true

  cluster_config {
    version_id = "2.0"

    hadoop {
      services        = ["HDFS", "SPARK", "YARN"]
      ssh_public_keys = [file(local.dp_ssh_key)]
    }

    subcluster_spec {
      name = "main"
      role = "MASTERNODE"
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 20 # GB
      }
      subnet_id   = yandex_vpc_subnet.dataproc_ch_subnet-a.id
      hosts_count = 1
    }

    subcluster_spec {
      name = "data"
      role = "DATANODE"
      resources {
        resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
        disk_type_id       = "network-hdd"
        disk_size          = 20 # GB
      }
      subnet_id   = yandex_vpc_subnet.dataproc_ch_subnet-a.id
      hosts_count = 1
    }
  }
}

resource "yandex_mdb_clickhouse_cluster" "mch-cluster" {
  description        = "Managed Service for ClickHouse cluster"
  name               = local.mch_name
  environment        = "PRODUCTION"
  network_id         = yandex_vpc_network.dataproc_ch_network.id
  security_group_ids = [yandex_vpc_security_group.mch_security_group.id]

  clickhouse {
    resources {
      resource_preset_id = "s2.micro" # 2 vCPU, 8 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = 10 # GB
    }
  }

  host {
    type             = "CLICKHOUSE"
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.dataproc_ch_subnet-a.id
    assign_public_ip = true # Required for connection from the Internet
  }

  database {
    name = local.mch_db_name
  }

  user {
    name     = local.mch_user_name
    password = local.mch_password
    permission {
      database_name = local.mch_db_name
    }
  }
}
