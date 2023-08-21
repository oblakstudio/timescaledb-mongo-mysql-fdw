#!/usr/bin/env bash

pg_ctlcluster 14 main start

tail -f /var/log/postgresql/postgresql-14-main.log
