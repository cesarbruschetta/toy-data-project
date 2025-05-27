FROM grafana/grafana-oss:latest-ubuntu

USER root
# Install plugins
RUN grafana cli --insecure plugins install trino-datasource
    
USER grafana