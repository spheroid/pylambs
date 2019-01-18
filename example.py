# @FunctionName: ExampleHandler
# @Includes: hello.py

from hello import message

def function_handler(event, context):
    return message()