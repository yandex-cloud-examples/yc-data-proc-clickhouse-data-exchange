# Exchanging data between Yandex Managed Service for ClickHouse® and Yandex Data Processing

With [Yandex Data Processing](https://yandex.cloud/en/docs/data-proc), you can transfer data between [Managed Service for ClickHouse®](https://yandex.cloud/en/docs/managed-clickhouse) and Spark DataFrame:

* Import data from Managed Service for ClickHouse® to Spark DataFrame.
* Export data from Spark DataFrame to Managed Service for ClickHouse®.

See [this tutorial](https://yandex.cloud/en/docs/tutorials/dataplatform/dp-mch-data-exchange) to learn how you set up the infrastructure for Managed Service for ClickHouse® and Yandex Data Processing through Terraform. This repository contains the configuration file you will need: [data-proc-data-exchange-with-mch.tf](data-proc-data-exchange-with-mch.tf).
