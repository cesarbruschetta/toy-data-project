import logging
from pydantic_settings import BaseSettings

from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, timestamp_millis
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    DoubleType,
    LongType,
)

logger = logging.getLogger(__name__)

SCHEMA_DATA = StructType(
    [
        StructField("sensor_id", StringType(), True),
        StructField("temperature", DoubleType(), True),
        StructField("humidity", DoubleType(), True),
        StructField("heat_index", DoubleType(), True),
        StructField("pressure", DoubleType(), True),
        StructField("altitude", DoubleType(), True),
        StructField("temperature_bmp", DoubleType(), True),
        StructField("timestamp", LongType(), True),
    ]
)


class Settings(BaseSettings):
    MINIO_ACCESS_KEY: str
    MINIO_SECRET_KEY: str
    MINIO_ENDPOINT: str
    MINIO_BUCKET: str

    KAFKA_BOOTSTRAP_SERVERS: str
    KAFKA_CONSUMER_TOPIC: str
    KAFKA_CONSUMER_GROUP: str = "HammConsumer"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


class HammConsumerKafkaToRawZone:
    def __init__(self) -> None:
        self.settings = Settings()

        logger.info("Starting spark session")
        self.spark = (
            SparkSession.builder.appName("HammConsumerTopicKafka")
            .config("fs.s3a.access.key", self.settings.MINIO_ACCESS_KEY)
            .config("fs.s3a.secret.key", self.settings.MINIO_SECRET_KEY)
            .config("fs.s3a.endpoint", self.settings.MINIO_ENDPOINT)
            .config("fs.s3a.path.style.access", "true")
            .config("fs.s3a.connection.ssl.enabled", "false")
            .config("fs.s3a.multipart.size", "104857600")
            .config(
                "spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem"
            )
            .config("spark.sql.session.timeZone", "UTC")
            .getOrCreate()
        )

        self.checkpoint = f"s3a://{self.settings.MINIO_BUCKET}/checkpoint/{self.settings.KAFKA_CONSUMER_TOPIC}"
        self.destination = f"s3a://{self.settings.MINIO_BUCKET}/raw/{self.settings.KAFKA_CONSUMER_TOPIC}"

    def run(self) -> None:
        logger.info("Starting read data from topic kafka")
        # Lê mensagens do Kafka
        df_raw = (
            self.spark.readStream.format("kafka")
            .option("kafka.bootstrap.servers", self.settings.KAFKA_BOOTSTRAP_SERVERS)
            .option("subscribe", self.settings.KAFKA_CONSUMER_TOPIC)
            .option("group.id", self.settings.KAFKA_CONSUMER_GROUP)
            .option("startingOffsets", "latest")
            .load()
        )
        # Converte os dados de Kafka de bytes para string e aplica o schema
        df_parsed = (
            df_raw.selectExpr("CAST(value AS STRING) as json_str")
            .select(from_json(col("json_str"), SCHEMA_DATA).alias("data"))
            .select("data.*")
        )
        # Adiciona a coluna de data de processamento
        df = df_parsed.withColumn(
            "timestamp", timestamp_millis(col("timestamp"))
        ).withColumn("dt", col("timestamp").cast("date"))

        # Mostra os dados no console (modo de debug ou exemplo simples)
        (
            df.writeStream.outputMode("append")
            .format("parquet")
            .partitionBy("dt")
            .option("path", self.destination)
            .option("checkpointLocation", self.checkpoint)
            .option("compression", "zstd")
            .trigger(processingTime="5 minutes")
            .start()
            .awaitTermination()
        )
        logger.info("Finished export data to s3a")
        self.spark.stop()
        logger.info("Finished spark session")


if __name__ == "__main__":
    obj = HammConsumerKafkaToRawZone()
    obj.run()
