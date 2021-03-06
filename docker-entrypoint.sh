#!/bin/bash
set -e

SEEDED=1

# read DATADIR from the MySQL config
DATADIR="$("$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

if [ ! -d "$DATADIR/mysql" ]; then
	SEEDED=0

	if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
		echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
		echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
		exit 1
	fi

	echo 'Running mysql_install_db ...'
	mysql_install_db --datadir="$DATADIR"
	echo 'Finished mysql_install_db'


	# These statements _must_ be on individual lines, and _must_ end with
	# semicolons (no line breaks or comments are permitted).
	# TODO proper SQL escaping on ALL the things D:
	
	tempSqlFile='/tmp/mysql-first-time.sql'
	cat > "$tempSqlFile" <<-EOSQL
		-- What's done in this file shouldn't be replicated
		--  or products like mysql-fabric won't work
		SET @@SESSION.SQL_LOG_BIN=0;
		
		DELETE FROM mysql.user ;
		CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
		DROP DATABASE IF EXISTS test ;
	EOSQL
	
	if [ "$MYSQL_DATABASE" ]; then
		echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" >> "$tempSqlFile"
	fi
	
	if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
		echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
		
		if [ "$MYSQL_DATABASE" ]; then
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" >> "$tempSqlFile"
		fi
	fi
	
	echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"
	
	MYSQL_PARAMS="--init-file=$tempSqlFile"

	#set -- "$@" 
fi

chown -R mysql:mysql "$DATADIR"

## Check during runtime if memory is low, then replace my.cnf with a minimal config
## See /proc/meminfo

# Before: 726835200
AVAILABLE_RAM=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
#echo "Available RAM: $AVAILABLE_RAM"
if [ $AVAILABLE_RAM -lt 1000000 ]; then
	echo "Low on RAM. Overriding my.cnf with a minimal config"
	cp /my-mini.cnf /etc/mysql/conf.d
fi

/usr/sbin/mysqld $MYSQL_PARAMS &

#exec "$@" &

MYSQL_PID=$!
RUNNING=0

# Loop while MySQL is running
set +e
while [ $RUNNING -eq 0 ]; do
	$(kill -0 $MYSQL_PID)
	if [ ! $? -eq 0 ]; then
		echo "Process has died mysteriously. Someone call Scooby Doo."
		RUNNING=255
	fi

	export MYSQL_PWD=$MYSQL_ROOT_PASSWORD

	if [ "$SEEDED" -eq 0 ] && [ -n "$S3_BUCKET" ] && [ -n "$S3_OBJ" ]; then
		echo "Connecting to Database..."
		echo 'SELECT 1' | mysql -u root  > /dev/null 2>&1
		LISTENING=$?
		

		if [ $LISTENING -eq 0 ]; then
			echo "Seeding $S3_OBJ from $S3_BUCKET"
			set -e
			set -o pipefail
			gof3r get -b $S3_BUCKET -k $S3_OBJ | pv --rate --bytes --name "From S3" | gunzip | mysql -u root
			if [ $? -eq 0 ]; then
				SEEDED=1
				echo "Database successfully seeded from S3."
			else
				echo "Seeding failed."
				exit 1
			fi
		fi
	fi

	
	sleep 5
done

# TODO: Capture stop signal and do a backup.