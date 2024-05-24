# Обмен данными между Yandex Managed Service for ClickHouse® и Yandex Data Proc

С помощью [Yandex Data Proc](https://yandex.cloud/ru/docs/data-proc) вы можете переносить данные между [Managed Service for ClickHouse®](https://yandex.cloud/ru/docs/managed-clickhouse) и Spark DataFrame:

* Загружать данные из Managed Service for ClickHouse® в Spark DataFrame.
* Выгружать данные из Spark DataFrame в Managed Service for ClickHouse®.

Подготовка инфраструктуры для Managed Service for ClickHouse® и Yandex Data Proc через Terraform описана в [практическом руководстве](https://yandex.cloud/ru/docs/tutorials/dataplatform/dp-mch-data-exchange), необходимый для настройки конфигурационный файл [data-proc-data-exchange-with-mch.tf](data-proc-data-exchange-with-mch.tf) расположен в этом репозитории.
