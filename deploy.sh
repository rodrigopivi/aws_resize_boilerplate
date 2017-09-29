#!/bin/bash
source ./config.sh

# Prevent infinite loop at lambda
if [ "$ORIGINAL_UPLOADS_S3_BUCKET" == "$RESIZED_S3_BUCKET" ]
then
    echo "======== ERROR: Your bucket names are the same, they need to be different to avoid an infinite loop."
    exit 1
fi

# Allow rebuild argument to reinstall all node_modules from docker image
if [[ "$1" == "rebuild" ]]
then
    echo "======== Rebuild - Removing lambda.zip and  lambda/node_modules to rebuild from docker image."
    rm -rf ./lambda.zip
    rm -rf ./lambda/node_modules
fi

# Allow rezip argument to create the zip file from the lambda directory
if [[ "$1" == "rezip" ]]
then
    echo "======== Rezip - Removing lambda.zip to re create it."
    rm -rf ./lambda.zip
fi

# Used cached lambda.zip if it exists else rebuild
if [ -e "./lambda.zip" ]
then
    echo "======== Lambda.zip already packed, skipping lambda build."
else
    sh ./build_lambda.sh
fi

# AWS orchestration:
echo "======== Creating temporary bucket for lambda code"
aws s3 mb s3://$LAMBDA_CODE_BUCKET

echo "======== Uploading lambda code to temporary bucket"
aws s3 cp ./lambda.zip s3://$LAMBDA_CODE_BUCKET/lambda.zip

echo "======== Deploying cloudformation stack"
aws cloudformation create-stack --stack-name $CLOUD_FORMATION_STACK_NAME --template-body file://template.json \
--capabilities CAPABILITY_IAM --parameters \
ParameterKey=ImageS3Bucket,ParameterValue=$ORIGINAL_UPLOADS_S3_BUCKET \
ParameterKey=ImageS3ResizedBucket,ParameterValue=$RESIZED_S3_BUCKET \
ParameterKey=LambdaS3Bucket,ParameterValue=$LAMBDA_CODE_BUCKET \
ParameterKey=ResizedBucketCustomPath,ParameterValue=$RESIZED_S3_BUCKET_CUSTOM_PATH \
ParameterKey=UploadsUserIAM,ParameterValue=$UPLOADS_USER_IAM

echo "======== Cloudformation deploy started... Waiting some minutes for complete confirmation..."
aws cloudformation wait stack-create-complete --stack-name $CLOUD_FORMATION_STACK_NAME && echo "STACK COMPLETED!"

echo "======== Removing temporary s3 bucket for lambda code"
aws s3 rb --force s3://$LAMBDA_CODE_BUCKET

