FROM ubuntu
LABEL org.opencontainers.image.source="https://github.com/oblakstudio/timescaledb-mongo-mysql-fdw"\
  org.opencontainers.image.authors="Oblak Studio <support@oblak.studio>" \
  org.opencontainers.image.title="TimescaleDB with Mongo and MySQL FDW" \
  org.opencontainers.image.description="TimescaleDB with Mongo and MySQL FDW" \
  org.opencontainers.image.licenses="MIT"


ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  gnupg \
  postgresql-common
RUN yes | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
RUN apt-get update && apt-get install -y \
  postgresql-14 \
  postgresql-server-dev-14  \
  gcc \
  cmake \
  libssl-dev \
  libkrb5-dev \
  git \
  nano \
  wget \
  sudo \
  netcat \
  pkg-config \
  libmysqlclient-dev
WORKDIR /tmp
RUN git clone https://github.com/timescale/timescaledb/
WORKDIR /tmp/timescaledb
RUN ./bootstrap
WORKDIR /tmp/timescaledb/build
RUN make
RUN make install -j
RUN echo "postgres ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN pg_dropcluster 14 main --stop
RUN pg_createcluster 14 main -- --auth-host=scram-sha-256 --auth-local=peer --encoding=utf8
USER postgres
RUN service postgresql start && \
  psql -U postgres -d postgres -c "alter user postgres with password 'postgres';" && \
  psql -U postgres -d postgres -c "alter system set listen_addresses to '*';" && \
  psql -U postgres -d postgres -c "alter system set shared_preload_libraries to 'timescaledb';"
RUN sed -i "s|# host    .*|host all all all scram-sha-256|g" /etc/postgresql/14/main/pg_hba.conf
RUN service postgresql restart && psql -X -c "create extension timescaledb;"

# installation of mongo_fdw
WORKDIR /tmp
RUN sudo git clone https://github.com/EnterpriseDB/mongo_fdw.git
WORKDIR /tmp/mongo_fdw
RUN sudo ./autogen.sh --with-master
RUN sudo make -f Makefile.meta
RUN sudo make -f Makefile.meta install
RUN service postgresql restart && psql -X -c "CREATE EXTENSION mongo_fdw;"

# installation of mysql_fdw
WORKDIR /tmp
RUN sudo git clone https://github.com/EnterpriseDB/mysql_fdw.git
WORKDIR /tmp/mysql_fdw
RUN sudo make USE_PGXS=1Z
RUN sudo make USE_PGXS=1 install
RUN service postgresql restart && psql -X -c "CREATE EXTENSION mysql_fdw;"

# Cleanup and exit
USER root
RUN sudo rm -rf /tmp/timescaledb /tmp/mongo_fdw /tmp/mysql_fdw
