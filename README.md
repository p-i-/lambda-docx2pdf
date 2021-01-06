TODO: Inspect https://github.com/wemake-services/wemake-django-template

Mainly reading from https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/

Taking Docker+Poetry tips from https://stackoverflow.com/questions/53835198/integrating-python-poetry-with-docker

```
> docker build -t lambda-test .

> docker run -p 9000:8080 lambda-test:latest
time="2021-01-05T16:30:43.314" level=info msg="exec '/usr/local/bin/python' (cwd=/home/app, handler=app.handler)"
time="2021-01-05T16:31:15.586" level=info msg="extensionsDisabledByLayer(/opt/disable-extensions-jwigqn8j) -> stat /opt/disable-extensions-jwigqn8j: no such file or directory"
time="2021-01-05T16:31:15.586" level=warning msg="Cannot list external agents" error="open /opt/extensions: no such file or directory"
START RequestId: 45b1c18b-20b7-4044-8aaa-fc3081595d5d Version: $LATEST
END RequestId: 45b1c18b-20b7-4044-8aaa-fc3081595d5d
REPORT RequestId: 45b1c18b-20b7-4044-8aaa-fc3081595d5d  Init Duration: 0.48 ms  Duration: 339.54 ms     Billed Duration: 400 ms Memory Size: 3008 MB    Max Memory Used: 3008 MB

> curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" -d '{}'
"Hello from AWS Lambda using Python3.9.1 (default, Dec 17 2020, 01:59:58) \n[GCC 9.3.0]!"

> aws ecr create-repository --repository-name ls-lambda
{
    "repository": {
        "repositoryArn": "arn:aws:ecr:us-east-1:795730031374:repository/ls-lambda",
        "registryId": "795730031374",
        "repositoryName": "ls-lambda",
        "repositoryUri": "795730031374.dkr.ecr.us-east-1.amazonaws.com/ls-lambda",
        "createdAt": "2021-01-05T23:46:32+07:00",
        "imageTagMutability": "MUTABLE",
        "imageScanningConfiguration": {
            "scanOnPush": false
        },
        "encryptionConfiguration": {
            "encryptionType": "AES256"
        }
    }
}

> docker images
> docker tag lambda-test:latest 795730031374.dkr.ecr.us-east-1.amazonaws.com/ls-lambda:latest

> # login to AWS/Docker
> aws ecr get-login-password | docker login --username AWS --password-stdin 795730031374.dkr.ecr.us-east-1.amazonaws.com

> docker push 795730031374.dkr.ecr.us-east-1.amazonaws.com/ls-lambda:latest
```

Now login to AWS -> Lambda and create a new function (DockerContainer)
Select the image and test it.

Dev-cycle:
```
> docker build -t lambda-test .  # --no-cache 

> docker tag lambda-test:latest 795730031374.dkr.ecr.us-east-1.amazonaws.com/ls-lambda:latest
> docker push 795730031374.dkr.ecr.us-east-1.amazonaws.com/ls-lambda:latest
```
(Have to "Deploy New Image" in AWS->Lambda each time we push)


# TODO: Automate deployment

https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-awscli.html

https://docs.aws.amazon.com/lambda/latest/dg/getting-started-create-function.html

```
aws lambda create-function \
    --function-name my-function \
    --package-type Image
    --handler my-function.handler \
```
"repositoryArn": "arn:aws:ecr:us-east-1:795730031374:repository/ls-lambda",
