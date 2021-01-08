#!/bin/bash

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#  H E L P E R S
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

# Color helper functions
red()    { echo -e "\n${RED}$1${RESET}"    ; }
blue()   { echo -e   "${BLUE}$1${RESET}"   ; }
green()  { echo -e   "${GREEN}$1${RESET}"  ; }
purple() { echo -e "\n${PURPLE}$1${RESET}" ; }
yellow() { echo -e   "${YELLOW}$1${RESET}" ; }

# - - - - - - -

🌷() {
    echo -en ${YELLOW}
    printf '🌷 %s\n' "$*"  # >&2 makes pipes work, even tho' they don't print properly
    echo -en ${RESET}
    "$@"
}
#+919028681113 Kiran
# - - - - - - -

assert_exists () {
    if hash $1 2>/dev/null; then
        green "$1 exists"
    else
        red "Fatal Error: $1 does not exist" >&2
        exit 1
    fi
}

check_cli_tools() {
    purple "Checking CLI tools"

    assert_exists docker
    assert_exists aws
    # assert_exists eksctl
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

# change to script's containing folder, and store it
cd `dirname "$0"`
SCRIPT_ROOT=`pwd -P`

all_args="$@"

cmd=$1
env_type=${2:-local}  # (local) | staging | production

AWS_ECR_REPO_NAME=ls-lambda-${env_type}
AWS_LAMBDAFUNC_NAME=ls-lambdafunc-${env_type}
DOCKER_IMAGE_TAG=ls-lambda-${env_type}
DOCKER_RUNNING_CONTAINER_NAME=ls-lambda-${env_type}

echo "AWS_ECR_REPO_NAME: $AWS_ECR_REPO_NAME"
echo "AWS_LAMBDA_NAME: $AWS_LAMBDA_NAME"
echo "DOCKER_IMAGE_TAG: $DOCKER_IMAGE_TAG"
echo "DOCKER_RUNNING_CONTAINER_NAME: $DOCKER_RUNNING_CONTAINER_NAME"

if aws ecr describe-repositories --repository-names ${AWS_ECR_REPO_NAME} 1>/dev/null; then
    green "Found AWS ECR repo: ${AWS_ECR_REPO_NAME}"
else
    purple "AWS ECR repo (${AWS_ECR_REPO_NAME}) not found, creating!"
    🌷 aws ecr create-repository --repository-name ${AWS_ECR_REPO_NAME}
fi

repo_info=$( aws ecr describe-repositories --repository-names $AWS_ECR_REPO_NAME | jq -r '.repositories[0]' )

# Note:
#   .repositoryArn gives e.g. arn:aws:ecr:us-east-1:795730031374:repository/foo, so we strip the /foo
lambda_uri=$( echo "$repo_info" | jq -r '.repositoryUri | split("/")[0]' )

echo -e "${GREEN}Lambda URI: ${YELLOW}$lambda_uri"  # e.g. 795730031374.dkr.ecr.us-east-1.amazonaws.com

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
#  S W I T C H B O A R D
# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

main() {
    # `set -v` (rather than -x) to echo commands
    # `set -e` to quit on error
    # `set -a` to store all defined vars in shell environment
    # (use + to OFF the flag)
    set -e

    if [ -z $cmd ] || [  $cmd = "help" ]; then
        green "`cat << EOF
Syntax:
    magic.sh Command [EnvType] [Options]

    EnvType: (local) staging production

    Command:
        build local|staging|production
            - builds image
            - runs it
            - tests with curl

        deploy staging|production
            - builds image
            - runs it
            - tests with curl
            - deploys to AWS
            - tests with curl
EOF
        `"
        exit 0
    fi

    check_cli_tools

    # # .env is always generated at project root
    # # Django looks for {project-root}/.env
    # # Docker Image for localdev copies this .env
    # generate_and_load_env .env
    # echo -en $YELLOW
    # cat .env
    # echo -en $RESET

    if [ $cmd = "setup" ]; then
        setup

    elif [ $cmd = "build" ]; then
        build

    elif [ $cmd = "deploy" ]; then
        deploy

    else
        red "Unknown command. 'magic.sh help' for available commands."
    fi
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

setup_one_time() {
    aws ecr create-repository --repository-name $AWS_ECR_REPO_NAME
}

# - - - - - - -

setup_one_time_per_devbox() {
    purple "One time!"

    mkdir -p ~/.aws-lambda-rie

    curl -Lo ~/.aws-lambda-rie/aws-lambda-rie \
        https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie

    chmod +x ~/.aws-lambda-rie/aws-lambda-rie
}

# - - - - - - -

setup() {
    echo "Empty"
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

build() {
    cd docker-image

    purple "Building Docker image"
    🌷 docker build -t $DOCKER_IMAGE_TAG .
    # 🌷 docker build -t $DOCKER_IMAGE_TAG --no-cache .

    # docker tag SOURCE_IMAGE[:TAG] TARGET_IMAGE[:TAG]
    purple "Tagging Docker image"
    🌷 docker tag $DOCKER_IMAGE_TAG:latest \
        ${lambda_uri}/${AWS_ECR_REPO_NAME}:latest

    # purple "remove if running container exists (safe to ignore error, it means local container not found"
    docker container inspect $DOCKER_RUNNING_CONTAINER_NAME 2>&1 >/dev/null \
        && 🌷 docker rm -f $DOCKER_RUNNING_CONTAINER_NAME
    # ^ We do this in case a previous build failed to complete, leaving a dangling running container

    purple "Running Docker image in daemon mode"
    🌷 docker run -d \
        -v ~/.aws-lambda-rie:/aws-lambda \
        -p 9000:8080 \
        --name $DOCKER_RUNNING_CONTAINER_NAME \
        --entrypoint /aws-lambda/aws-lambda-rie \
        $DOCKER_IMAGE_TAG:latest \
            /entry.sh app.handler

    🌷 sleep 10

    purple "Testing endpoint"
    🌷 curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
        -d '{"filename" : "test-template.docx"}'

    echo
    purple "Deleting local Docker container instance"
    🌷 docker rm -f $DOCKER_RUNNING_CONTAINER_NAME
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

deploy() {
    # 🌷 cd docker-image

    # TODO: Fix this (currently fetching it from AWS)
    role_arn=arn:aws:iam::795730031374:role/service-role/ls-lambda-role-ka10n7ab

    # Can't mix 🌷 with pipes, so we print the command manually
    yellow "🌷 aws ecr get-login-password | docker login --username AWS --password-stdin $lambda_uri"
    aws ecr get-login-password | \
        docker login \
            --username AWS \
            --password-stdin \
            $lambda_uri

    full_url=$lambda_uri/${AWS_ECR_REPO_NAME}:latest

    🌷 docker push $full_url

    🌷 aws lambda delete-function  \
        --function-name $AWS_LAMBDAFUNC_NAME

    🌷 aws lambda create-function  \
        --function-name $AWS_LAMBDAFUNC_NAME \
        --role $role_arn \
        --code ImageUri=$full_url \
        --package-type Image \
        --memory-size 8192 \
        --timeout 300 \
        --publish \
        | cat  # avoid requiring user interaction for multipage output

    🌷 sleep 30

    # 🌷 aws lambda invoke \
    #     --function-name $AWS_LAMBDAFUNC_NAME \
    #     output.txt

    # green "$(cat output.txt)"
    # rm output.txt

    # 🌷 aws lambda invoke \
    #     --function-name $AWS_LAMBDAFUNC_NAME \
    #     --payload '{"filename" : "test-template.docx"}' \
    #     output.txt

    🌷 aws lambda invoke \
        --function-name $AWS_LAMBDAFUNC_NAME \
        --payload fileb://invoke-payload.json \
        output.txt

    echo "$(cat output.txt)"
    cat output.txt | jq
    rm output.txt
}

# = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

main "$@"
