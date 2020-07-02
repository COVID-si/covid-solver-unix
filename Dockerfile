FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install -y wget zip unzip curl expect && \
    mkdir -p /app && \
    wget -O /app/covid-linux.zip "https://github.com/COVID-si/covid-solver-unix/releases/latest/download/covid-linux64.zip" && \
    unzip /app/covid-linux.zip -d /app

WORKDIR /app

COPY docker-run.sh /app
RUN chmod +x /app/docker-run.sh
ENTRYPOINT ["/app/docker-run.sh"]

# Threads, Priority: -20 (highest) - 19 (lowest), RxDock output files
CMD ["All", "0", "no"]

