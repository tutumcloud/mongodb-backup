#!/bin/bash

MONGODB_HOST=${MONGODB_PORT_27017_TCP_ADDR:-${MONGODB_HOST}}
MONGODB_HOST=${MONGODB_PORT_1_27017_TCP_ADDR:-${MONGODB_HOST}}
MONGODB_PORT=${MONGODB_PORT_27017_TCP_PORT:-${MONGODB_PORT}}
MONGODB_PORT=${MONGODB_PORT_1_27017_TCP_PORT:-${MONGODB_PORT}}
MONGODB_USER=${MONGODB_USER:-${MONGODB_ENV_MONGODB_USER}}
MONGODB_PASS=${MONGODB_PASS:-${MONGODB_ENV_MONGODB_PASS}}

[[ ( -z "${MONGODB_USER}" ) && ( -n "${MONGODB_PASS}" ) ]] && MONGODB_USER='admin'

[[ ( -n "${MONGODB_USER}" ) ]] && USER_STR=" --username ${MONGODB_USER}"
[[ ( -n "${MONGODB_PASS}" ) ]] && PASS_STR=" --password ${MONGODB_PASS}"
[[ ( -n "${MONGODB_DB}" ) ]] && DB_STR=" --db ${MONGODB_DB}"

BACKUP_CMD="mongodump --out /backup/"'${BACKUP_NAME}'" --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_STR}${PASS_STR}${DB_STR} ${EXTRA_OPTS}"

echo "=> Creating backup script"
rm -f /backup.sh
cat <<EOF >> /backup.sh
#!/bin/bash
MAX_BACKUPS=${MAX_BACKUPS}
BACKUP_NAME=\$(date +\%Y.\%m.\%d.\%H\%M\%S)

echo "=> Backup started"
if ${BACKUP_CMD} ;then
    echo "   Backup succeeded"
else
    echo "   Backup failed"
    rm -rf /backup/\${BACKUP_NAME}
fi

if [ -n "\${MAX_BACKUPS}" ]; then
    while [ \$(ls /backup -N1 | wc -l) -gt \${MAX_BACKUPS} ];
    do
        BACKUP_TO_BE_DELETED=\$(ls /backup -N1 | sort | head -n 1)
        echo "   Deleting backup \${BACKUP_TO_BE_DELETED}"
        rm -rf /backup/\${BACKUP_TO_BE_DELETED}
    done
fi
echo "=> Backup done"
EOF
chmod +x /backup.sh

echo "=> Creating restore script"
rm -f /restore.sh
cat <<EOF >> /restore.sh
#!/bin/bash
echo "=> Restore database from \$1"
if mongorestore --host ${MONGODB_HOST} --port ${MONGODB_PORT} ${USER_STR}${PASS_STR} \$1; then
    echo "   Restore succeeded"
else
    echo "   Restore failed"
fi
echo "=> Done"
EOF
chmod +x /restore.sh

touch /mongo_backup.log
tail -F /mongo_backup.log &

if [ -n "${INIT_BACKUP}" ]; then
    echo "=> Create a backup on the startup"
    /backup.sh
fi

echo "${CRON_TIME} /backup.sh >> /mongo_backup.log 2>&1" > /crontab.conf
crontab  /crontab.conf
echo "=> Running cron job"
exec cron -f
