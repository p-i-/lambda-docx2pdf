https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/

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
```

