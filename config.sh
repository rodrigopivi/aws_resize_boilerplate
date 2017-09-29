# Bucket name that will be crated and is where users upload the original files
export ORIGINAL_UPLOADS_S3_BUCKET=my_bucket_name_for_uploads

# You need to create it manually previously, this bucket name is where the files go after processing
# this needs to be a different bucket than the ORIGINAL_UPLOADS_S3_BUCKET, else we get an inifnite loop.
export RESIZED_S3_BUCKET=public_content_bucket_name

# Path that is used as root for resized objects, must end with '/'.
export RESIZED_S3_BUCKET_CUSTOM_PATH=some_path_at_public_content_bucket/

# The IAM user arn that will have permision to upload to the RESIZED_S3_BUCKET_CUSTOM_PATH.
# When creating signed url's for direct upload they get signed using this user credentials.
# More info at https://console.aws.amazon.com/iam/home?region=us-east-1#/users
export UPLOADS_USER_IAM=arn:aws:iam::007:user/james_bond

# Referential name for the cloudformation config at aws dashboard
export CLOUD_FORMATION_STACK_NAME=my_aws_stack_name

# AWS region
export AWS_DEFAULT_REGION=us-east-1

# Temporary bucket name, this is non important as this bucket will be removed when deploy ends
export LAMBDA_CODE_BUCKET=temp_bucket_for_images_resizer_code
