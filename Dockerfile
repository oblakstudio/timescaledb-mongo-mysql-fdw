FROM ubuntu:jammy as base

ARG DEBIAN_FRONTEND=noninteractive
RUN rm -f /etc/apt/apt.conf.d/docker-clean
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
  --mount=target=/var/cache/apt,type=cache,sharing=locked \
  apt-get update \
  && apt-get -y --no-install-recommends install \
  curl \
  debian-keyring \
  debian-archive-keyring \
  apt-transport-https \
  gnupg \
  ca-certificates \
  net-tools

RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ bookworm main" | tee /etc/apt/sources.list.d/timescaledb.list
RUN curl -sSL https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor | apt-key add -
RUN curl -1sLf 'https://downloads.enterprisedb.com/WWyW67XPeT8AYO2pfRepCRogiYvOwHrz/enterprise/gpg.E71EB0829F1EF813.key' |  gpg --dearmor > /usr/share/keyrings/enterprisedb-enterprise-archive-keyring.gpg
RUN curl -1sLf 'https://downloads.enterprisedb.com/WWyW67XPeT8AYO2pfRepCRogiYvOwHrz/enterprise/config.deb.txt?distro=ubuntu&codename=jammy' > /etc/apt/sources.list.d/enterprisedb-enterprise.list

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
  --mount=target=/var/cache/apt,type=cache,sharing=locked \
  apt-get update && apt-get -y --no-install-recommends install \
  postgresql-common \
  postgresql-14 \
  postgresql-server-dev-14  \
  postgresql-14-cron \
  libmysqlclient-dev \
  timescaledb-2-postgresql-14 \
  postgresql-14-mongo-fdw \
  postgresql-14-mysql-fdw

RUN yes | /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh

# RUN rm /etc/postgresql/14/main/postgresql.conf
# COPY ./postgresql.conf /etc/postgresql/14/main/



USER postgres
RUN pg_dropcluster 14 main --stop
RUN pg_createcluster 14 main -- --auth-host=scram-sha-256 --auth-local=peer --encoding=utf8
USER postgres
RUN service postgresql start
RUN pg_ctlcluster 14 main start && \
  psql -U postgres -d postgres -c "alter user postgres with password 'postgres';" && \
  psql -U postgres -d postgres -c "alter system set listen_addresses to '*';" && \
  psql -U postgres -d postgres -c "alter system set shared_preload_libraries to 'timescaledb';" &&\
  psql -U postgres -d postgres -c "alter system set shared_preload_libraries='timescaledb','pg_cron';"

RUN service postgresql restart
RUN pg_ctlcluster 14 main start && psql -U postgres -d postgres -c "CREATE EXTENSION timescaledb;" &&\
  psql -U postgres -d postgres -c "CREATE EXTENSION mongo_fdw;" &&\
  psql -U postgres -d postgres -c "CREATE EXTENSION mysql_fdw;"
# RUN psql -U postgres -d postgres -c "CREATE EXTENSION pg_cron;"

USER root
RUN apt-get remove -y build-essential \
  curl \
  debian-keyring \
  debian-archive-keyring \
  apt-transport-https \
  gnupg \
  && apt autoremove -y

FROM scratch as final
COPY --from=base // /
EXPOSE 5432
WORKDIR /usr/bin
COPY ./entrypoint.sh ./
RUN chmod +x /usr/bin/entrypoint.sh
USER postgres
ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]
