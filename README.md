# mysql-from-s3

It's essentially "[mysql:5.6](https://registry.hub.docker.com/_/mysql/)" from the official builds on Docker Hub, with a twist. You can find an automated build on [Docker Hub](https://registry.hub.docker.com/u/andrioid/mysql-from-s3/).

## Introduction

MySQL server that will seed the database from a gzipped dump file on S3 when run for the first time.

I use s3gof3r to stream the compressed dump file from S3.

## Use Cases


### Staging Server
Some companies like to run staging on actual data, but doing it in production can cause problems. A backup-script runs daily on the production database and pushes a gzipped dump-file to S3.

Then run mysql-from-s3 with Docker without mounting the /var/lib/mysql volume. That way, a fresh database is seeded from S3, every time you restart the server. It also helps making sure that your database backups are working.


### Personal Blog
I have a Drupal site and it's driving me crazy. I spend more time upgrading Drupal, than writing stuff on my site. 

If the host-machine dies, the worst case scenario is that I have to roll back to the latest backup. I can live with that.

This requires mounting the /var/lib/mysql to a host-directory. That way, you can restart the container without losing data and re-initializing from S3.

## Configuration

- S3_BUCKET: Name of the S3 Bucket
- S3_OBJ: Object name (with prefix)
- AWS_ACCESS_KEY_ID: IAM key
- AWS_SECRET_ACCESS_KEY=none: IAM secret (has to have S3 read access)
- MYSQL_ROOT_PASSWORD

You also have to add a volume for /var/lib/mysql if you don't want the container to seed every time you run it.

If you have plans to use this as a personal DB. I strongly recommend that you automatically backup your database to S3.

## Example

``docker run -t -i -e AWS_ACCESS_KEY_ID=editme -e AWS_SECRET_ACCESS_KEY=editme -e S3_BUCKET=editme -e S3_OBJ=backup/editme.sql.gz -e MYSQL_ROOT_PASSWORD=editme -p 3306:3306 andrioid/mysql-from-s3``