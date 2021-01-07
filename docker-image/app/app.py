import json

import platform
print(platform.python_version())

def handler(event, context): 
    return f'Hello from AWS Lambda using Python {platform.python_version()}, Event data: {json.dumps(event)}'
