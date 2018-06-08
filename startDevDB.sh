#!/bin/bash
set -euo pipefail

DATA_DIR=/Users/lerk/workspace/fediverse-network/data

docker run -d --name timescaledb -v $DATA_DIR:/var/lib/postgresql/data -e POSTGRES_PASSWORD=postgres -p 5432:5432 timescale/timescaledb:latest-pg9.6
