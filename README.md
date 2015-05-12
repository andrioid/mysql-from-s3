# mysql-from-s3

It's essentially "[mysql:5.6](https://registry.hub.docker.com/_/mysql/)" from the official builds on Docker Hub, with a twist.

## Introduction

MySQL server that will seed the database from a gzipped dump file on S3 when run for the first time.

I use s3gof3r to stream the compressed dump file from S3.

## Use Cases

- Staging or Development. Allows you to bootstrap your environment fast.
- Personal Blog or whatever. Something that you don't change too often and are essentially fine with restoring from backup, should shit happen.

## Configuration

- S3_BUCKET: Name of the S3 Bucket
- S3_OBJ: Object name (with prefix)
- AWS_ACCESS_KEY_ID: IAM key
- AWS_SECRET_ACCESS_KEY=none: IAM secret (has to have S3 read access)