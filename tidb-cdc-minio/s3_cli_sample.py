#!/usr/bin/env python3

import boto3

# Set up the S3-compatible client
s3 = boto3.client(
        's3', 
        endpoint_url='http://localhost:9000',
        aws_access_key_id='minioadmin',
        aws_secret_access_key='minioadmin',
        )

# Specify the bucket name and object key
bucket_name = 'test-bucket'
object_key = 'test-object.txt'

response = s3.list_buckets()
buckets = [bucket['Name'] for bucket in response['Buckets']]
if bucket_name not in buckets:
    s3.create_bucket(Bucket=bucket_name)
    print(f'Create bucket {bucket_name}')

# Specify the string to write
content = 'This is the content of the file.'

# Convert the string to bytes
content_bytes = content.encode('utf-8')

# Upload the content as an object to S3
s3.put_object(Body=content_bytes, Bucket=bucket_name, Key=object_key)

print('String written to S3 successfully!')
