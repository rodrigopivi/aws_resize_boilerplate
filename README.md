# AWS_RESIZE_BOILERPLATE
### A Production ready serverless image resizer and optimizer
The motivation behind this project is to offer a well documented boilerplate for setting up a serverless image processing (resizing) and optimization (compression) service. If you are a noob with DevOps, AWS or Docker, this project will be a good ground to gain familarity, and at the same time offers a production ready implementation for optimized images resizing.

##  Overview
If you are not familiar with some of the technologies used, here is a description of the usage we give them in this project:

- AWS CloudFormation - Service to automate the orchestration (creation and configuration) of AWS resources (S3 and Lambda) using a template.json file.
- AWS S3 - Service we use to store images and triggers the lambda function at new uploads on the upload bucket.
- AWS Lambda - Service we use to runs a nodejs function that gets called by S3 after a new upload, resizes, optimizes the image, and uploads it back at another S3 bucket. To use Lambda, we need to pack the lambda directory as a zip file and upload it to the service.
- Docker - A tool that we use to build native dependencies that match the AWS lambda linux architecture.

### Architecture

![Image resizing process](./lambda_resize.png?raw=true "Image resizing process")

The solution makes use of two S3 buckets:
* BUCKET A (original files) -> Auto created by the script with only permissions to restricted signed uploads, so that users can only do direct uploads to it. Here we keep all the original files. This bucket triggers the lambda function after each upload.

* BUCKET B (resized files) -> Not auto created by the script. Here is where the resized images go.

NOTE: We need two buckets to avoid an infinite loop caused by lambda and s3 triggers.

When you upload an image to `Bucket A`, the Lambda function is executed. The Lambda function downloads the image, creates multiple resized versions and uploads them to `Bucket B`. The number of resize images as well as their graphics magick resize settings is defined at `./lambda/config.js`.

### Workflow example
NOTE: Check the config file `config.sh` to see how the variables there fit at the path generation.

- A user uploads `test.jpg` directly to bucket `my_bucket_name_for_uploads` using a signed PUT request. The file is now located at `s3.amazonaws.com/my_bucket_name/some_path/test.jpg` but its not publicly available, because the bucket has only permissions to upload, not read.

- The uploaded file triggers an event at S3 which is configured to trigger the lambda function. The function then generates the resized images and uploads them to the `public_content_bucket_name` bucket. We should have 3 optimized and resized images:
```
s3.amazonaws.com/public_content_bucket_name/some_path_at_public_content_bucket/some_path/test.jpg
s3.amazonaws.com/public_content_bucket_name/some_path_at_public_content_bucket/some_path/test_thumb.jpg
s3.amazonaws.com/public_content_bucket_name/some_path_at_public_content_bucket/some_path/test_avatar.jpg
```

## Setup
- Install [docker](https://www.docker.com/community-edition)

¿Why we need Docker? Because for image compression, we use mozjpeg and pngquant which are fantastic at reducing images file sizes but require to be built from source, and Lambda requires us to provide binary files that match their linux architecture. So instead of providing pre built binaries (which is a security risk), we use a docker container to build them.

- Install [AWS Command Line Interface](https://aws.amazon.com/cli/). Here are some quick install instructions for mac:
```
brew install python3
pip3 install awscli
```
Then setup your AWS credentials. If you don't have credentials, go to [AWS web client](https://console.aws.amazon.com) > Services > I Am > Users > Select a user > Security Credentials > Genearate a new key. Make sure your credentials have enough permissions for our services orchestration:
```
aws configure
```

### Conditional setup step
- Create the public S3 bucket(BUCKET B), this is where the resized images will go and from where users download the images. We dont auto-create this bucket (as is done for BUCKET A) because one may want to reuse a previously created bucket, so if you want to reuse an already craeted bucket, you can just use that bucket name, else run (update with your bucket name):
```
aws s3 mb s3://public_content_bucket_name
```

We need to be sure users can have access to see the images. For this, go to [AWS S3 web console](https://s3.console.aws.amazon.com/s3/home) and at the bucket permissions tab, enter a policy like this (update with your bucket name):
```
{
    "Version": "2012-10-17",
    "Id": "Policy1487736384502",
    "Statement": [
        {
            "Sid": "Stmt1487736377514",
            "Effect": "Allow",
            "Principal": "*",
            "Action": ["s3:GetObject"],
            "Resource": "arn:aws:s3:::public_content_bucket_name/*"
        }
    ]
}
```

## Configuration
- Open `lambda/config.js`. There you can personalize the resize command dimensions used by graphics magic, as well as the suffix added to the uploaded file.

- Open `config.sh`. Fill the configuration parameters, they are well documented on the file.

## Deploy
CloudFormation to orchestrates the creation and configuration of the S3 bucket and the lambda service, Docker is used to build the `./lambda/node_modules` directory because it needs to match the Lambda linux architecture. The automation of this is at `deploy.sh`, the source is well documented for you to take a look.

### Deployment with cache
```
sh ./deploy.sh
```
If `lambda.zip` file is present, it uses it skipping the docker build, and just deploys to AWS.
If `lambda/node_modules` is present, it will skip building it using docker. It just creates the zip file and deploys to AWS.
If neither `lambda.zip` and `lambda/node_modules` are present, it will run `sh build_lambda.sh` to start the docker container, build the dependencies, copy the node_modules from the container and create the lambda.zip file. Then deploy to AWS.

### Deployment without cache
```
sh ./deploy.sh rebuild
```
It deletes `lambda.zip` and `lambda/node_modules` to trigger the full build and deploy it.

### Test after deploy
After deployment is done, you can verify at the AWS web client that your account now has a new CloudFormation Stack, a new S3 bucket and a new Lambda function set up. You can now test uploading an image to the uploads bucket with:
```
aws s3 cp test.jpg s3://my_bucket_name_for_uploads/some_path/test.jpg
```
And expect to get the same files generated as described by the workflow example section.

## Extras

### Extend
Feel free to add gif processing, video processing, etc... on demand. Just make sure to update the docker image accordingly if you need to introduce a new linux level dependency by removing the previous image. And make sure you rebuild the deploy if you change any node packages dependency.

### Cloudformation template config
All the definitions are at `template.json` including the auto-created S3 bucket policy. Get familiar with the AWS Cloudformation [template documentation](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html).

### About using docker
We use docker to build the npm dependencies for the lambda architecture, the dependencies for image compression (mozjpeg and pngquant) are c libraries that need to be built at the correct linux architecture for AWS Lambda or else it will crash on runtime.

Keep familiarity with docker concepts of images and containers:

- An [image](https://docs.docker.com/glossary/?term=image) is the the base for a container. Here we build a new image on top of the "amazonlinux" official parent image and setup dependencies (like gcc-c++, make and libpng-devel) that we will need to build the npm dependencies). The definitions for our `aws_resize` image are at `Dockerfile`.

- A [container](https://docs.docker.com/glossary/?term=container) is a runtime instance of a docker image. We use the container to install/build the npm dependencies and copy the resulting `node_modules` from the container to the host lambda folder.

The orchestration of our image and container is done at `build_lambda.sh`, that automatically creates the image, the container, builds the npm dependencies, copies the node_modules to lambda directory, packs the lambda.zip file and clears the created container.

### Docker commands cheat-sheet

Take a look at build_lambda.sh to get familiar with how we automate the usage of this commands.

To list all containers and images:
```
docker ps -a
docker images -a
```

To stop and remove all docker containers:
```
docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)
```

To build the image and then run a container of that image:
```
 docker build -t aws_resize .
 docker run -d --name aws_resize_container aws_resize
```

To remove the created container and image:
```
docker stop aws_resize_container && docker rm aws_resize_container
docker rmi aws_resize
```

### Manually removing the AWS services
NOTE: Be careful with this commands as they will remove aws infrastructure. Please remove the bucket first or else deleting the cloudformation stack could fail.

To remove the auto-created bucket:
```
source config.sh && aws s3 rb --force s3://$ORIGINAL_UPLOADS_S3_BUCKET
```

Delete the CloudFormation stack. (This removes the lambda function too).
```
source config.sh && aws cloudformation delete-stack --stack-name $CLOUD_FORMATION_STACK_NAME
```

### Credits
This project is heavily influenced by:

- https://github.com/AWSinAction/lambda - Same lambda architecture, but no image optimization.
- https://github.com/awslabs/serverless-image-resizing - Different architecture (images are not processed after upload, but instead when requested), no image optimization.
- https://github.com/ysugimoto/aws-lambda-image - Same lambda architecture, offers optimization, but comes with pre-built binaries with is a seccurity risk and is not good for boilerplate) 
