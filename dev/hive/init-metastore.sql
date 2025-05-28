-- Create the database and table for the raw data
CREATE DATABASE toy_data_raw
LOCATION 's3a://dl-test-localstack/raw/'

-- Create the table for the raw data
CREATE EXTERNAL TABLE IF NOT EXISTS toy_data_raw.sensor_readings (
    sensor_id STRING,
    temperature DOUBLE,
    humidity DOUBLE,
    heat_index DOUBLE,
    pressure DOUBLE,
    altitude DOUBLE,
    temperature_bmp DOUBLE,
    `timestamp` TIMESTAMP
)
PARTITIONED BY (dt DATE)
STORED AS PARQUET
LOCATION 's3a://dl-test-localstack/raw/toydata-topic-temperature-v1'
TBLPROPERTIES (
    'parquet.compression' = 'ZSTD'
);

-- Load the data into the table
MSCK REPAIR TABLE toy_data_raw.sensor_readings;