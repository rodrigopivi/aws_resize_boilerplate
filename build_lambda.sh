# Build node_modules using docker because of the native binary dependencies
if [ -d "lambda/node_modules" ]
then
    echo "======== Directory ./lambda/node_modules already exists, skipping building it from docker"
else
    echo "======== Building node_modules from docker image to get correct binary dependencies for lambda"
    if [[ $(docker images -q aws_resize) == "" ]]
    then
        echo "======== Building docker image for aws_resize from scratch"
        # build docker image
        docker build -t aws_resize .
    else
        echo "======== Docker image aws_resize, skipping building it from scratch"
    fi
    
    # create container running docker image
    docker run -it -d --name aws_resize_container aws_resize

    # copy package.json to container to prepare for building dependencies natively
    docker cp ./lambda/package.json aws_resize_container:/aws_resize/package.json
    docker cp ./lambda/package-lock.json aws_resize_container:/aws_resize/package-lock.json

    # run the npm install at the container
    docker exec aws_resize_container npm i

    # copy built node_modules from container to local
    docker cp aws_resize_container:/aws_resize/node_modules ./lambda/.

    # cleanup container
    docker stop aws_resize_container
    docker rm aws_resize_container
    # docker rmi aws_resize # lets keep the image, else uncomment this line
    echo "======== DONE!"
fi

# pack the code for lambda
rm -rf lambda.zip
cd lambda && zip -r ../lambda.zip * && cd ..

