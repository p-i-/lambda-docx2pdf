import sys
import json


def handler(event, context): 
    # TODO "Event data:" + event.dumps()
    return 'Hello from AWS Lambda using Python' + sys.version + '!' + 'Event data:' + json.dumps(event)
