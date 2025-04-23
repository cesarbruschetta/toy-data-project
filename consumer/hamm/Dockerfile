FROM bitnami/spark:3.5.5

ADD ./src/main.py /app/hamm_consumer.py
ADD ./requirements.txt /app/requirements.txt

RUN pip install -r /app/requirements.txt 

CMD /opt/bitnami/spark/bin/spark-submit \
    --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 \
    --repositories https://repo1.maven.org/maven2 \
    /app/hamm_consumer.py