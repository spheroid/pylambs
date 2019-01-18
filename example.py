# @FunctionName: ExampleHandler
# @Includes: hello.py
# @Region: eu-central-1

from hello import message

def function_handler(event, context):
    return message()