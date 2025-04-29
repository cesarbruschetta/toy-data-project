FROM apache/hive:4.0.1

# Diretório padrão onde o Hive espera os JARs
ENV HIVE_HOME=/opt/hive
ENV HADOOP_HOME=/opt/hadoop
ENV HIVE_LIB_DIR=$HIVE_HOME/lib

# Instala o curl
USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Baixar as bibliotecas diretamente do Maven Central
RUN curl -L -o $HIVE_LIB_DIR/aws-java-sdk-bundle-1.12.367.jar \
      https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.367/aws-java-sdk-bundle-1.12.367.jar && \
    curl -L -o $HIVE_LIB_DIR/hadoop-aws-3.3.4.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar
