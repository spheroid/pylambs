# PyLambs

A simple Makefile-based toolchain for deploying Python-based Lambdas into AWS with minimal configuration and hassle.

## Usage

1. Copy the Makefile into your working directory
2. Make a Python file and define a function called `lambda_handler` as the entry point
3. Define at least the Lambda function name using a **@FunctionName** annotation
4. You're ready to deploy it

## Deploying

Creating the function in AWS is very simple:

```
$ make create -m NAME=function
```

Replace `function` with whatever you chose to call your Python file (without the .py extension, that is). If you have not set up AWS CLI with default profile, either define AWS_PROFILE using environment variables or similarly with `-m`

Updating existing functions is even more easier:

```
$ make update
```

It assumes the AWS_PROFILE is set, as above, and it also assumes that the functions are already created.

## Annotations

The annotations should be placed in comments like this:

```
# @FunctionName: MyExampleFunction
# @Requires: pytz
```

This will set the Lambda function name to _MyExampleFunction_ and adds _pytz_ PyPI package as a built-in requirement (which is then automagically installed inside the deploy bundle). Whitespace is not relevant, but do not add any other text on the same line.

The available annotations are:

* **@FunctionName:** sets the function name. **This is required**.
* **@Requires:** adds the defined PyPI package as an requirement. This can be defined multiple times or you can define all requirements on a single line. But do keep in mind that if you need to set any version definitions, they must not contain any whitespace.
* **@Includes:** can be used to copy additional files and folders to the deployment package. Behaves exactly like *@Requires*, but performs `cp` on the arguments instead of `pip install`.

And these extra annotations are used when creating new functions:

* **@ExecutionRole:** can be used to set the IAM execution role. The short name is automatically expanded to full ARN using the current user credentials.
* **@Timeout:** sets the timeout for the function.
