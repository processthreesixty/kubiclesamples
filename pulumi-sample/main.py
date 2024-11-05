import pulumi
import pulumi_aws as aws

# Create an S3 bucket
bucket = aws.s3.Bucket('my-bucket',
                       acl='private')

pulumi.export('bucket_name', bucket.id)
