#!/bin/bash

export LANGUAGE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

akka_apps_status=$(systemctl is-active "bbb-apps-akka")
hasura_status=$(systemctl is-active "bbb-graphql-server")

if [ "$akka_apps_status" = "active" ]; then
  echo "Stopping Akka-apps"
  sudo systemctl stop bbb-apps-akka
fi
if [ "$hasura_status" = "active" ]; then
  echo "Stopping Hasura"
  sudo systemctl stop bbb-graphql-server
fi

echo "Restarting database bbb_graphql"
sudo -u postgres psql -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE datname = 'bbb_graphql'"
sudo -u postgres psql -c "drop database if exists bbb_graphql with (force)"
sudo -u postgres psql -c "create database bbb_graphql WITH TEMPLATE template0 LC_COLLATE 'C.UTF-8'"
sudo -u postgres psql -c "alter database bbb_graphql set timezone to 'UTC'"

echo "Creating tables in bbb_graphql"
sudo -u postgres psql -U postgres -d bbb_graphql -q -f bbb_schema.sql --set ON_ERROR_STOP=on

if [ "$hasura_status" = "active" ]; then
  echo "Starting Hasura"
  sudo systemctl start bbb-graphql-server

  #Check if Hasura is ready before applying metadata
  HASURA_PORT=8080
  while ! netstat -tuln | grep ":$HASURA_PORT " > /dev/null; do
      echo "Waiting for Hasura's port ($HASURA_PORT) to be ready..."
      sleep 1
  done
fi
if [ "$akka_apps_status" = "active" ]; then
  echo "Starting Akka-apps"
  sudo systemctl start bbb-apps-akka
fi

echo "Applying new metadata to Hasura"
hasura metadata apply
