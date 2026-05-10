#!/bin/bash
until mariadb-admin ping -h systemd-db -u root --password=123 --silent; do
  echo "waiting for db..."
  sleep 2
done
ls -1 apps > sites/apps.txt
bench set-config -g db_host $DB_HOST
bench set-config -gp db_port $DB_PORT
bench set-config -g redis_cache "redis://$REDIS_CACHE"
bench set-config -g redis_queue "redis://$REDIS_QUEUE"
bench set-config -g redis_socketio "redis://$REDIS_QUEUE"
bench set-config -gp socketio_port $SOCKETIO_PORT
bench set-config -g chromium_path /usr/bin/chromium-headless-shell
