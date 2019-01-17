AWS_CLI_PATH=/usr/bin/env aws
PIP_PATH=/usr/local/bin/pip3

TARGET_DIR = target
BUILD_DIR = build
LAMBDAS = $(wildcard *.py)
PACKAGES = $(LAMBDAS:%.py=$(TARGET_DIR)/%.zip)
RECEIPTS = $(LAMBDAS:%.py=$(TARGET_DIR)/%.receipt)

default:
	@echo "Usage: make build|update"

build: $(PACKAGES)

update: $(RECEIPTS)

ifdef NAME
  CREATE_FUNC_PKG=$(TARGET_DIR)/$(NAME).zip
endif

create: $(CREATE_FUNC_PKG)
ifndef NAME
	$(error You need to define the function name with `-m NAME=function')
endif
	@$(call create-function,$(NAME).py,$(TARGET_DIR)/$(NAME).zip)

$(TARGET_DIR)/%.receipt: $(TARGET_DIR)/%.zip
	@echo -n 'Deploying... '
	@out=`$(call update-function,$(<:$(TARGET_DIR)/%.zip=%.py),$<)`; \
	if [ $$? -ne 0 ]; then \
	echo failed; \
	exit 1; \
	fi; \
	echo $$out > $@
	@echo ok

$(TARGET_DIR)/%.zip: %.py
	@echo -n 'Creating package... '
	@out=`$(call create-package,$<,$@)`; \
	if [ $$? -ne 0 ]; then \
	echo failed; \
	echo $$out > build.log; \
	exit 1; \
	fi
	@echo ok

$(PACKAGES): | $(TARGET_DIR)

$(TARGET_DIR):
	mkdir $(TARGET_DIR)

create-package = $(call expand-package-props,$1,$2,$(2:$(TARGET_DIR)/%.zip=%.py))
expand-package-props = $(call do-create-package,$1,$2,$(call get-property,$3,Requires))
do-create-package = \
	mkdir -p $(BUILD_DIR); \
	cd $(BUILD_DIR); \
	echo "[install]\nprefix=\n" > setup.cfg; \
	cp ../$(1) ./function.py; \
	if [[ "$(3)" != "" ]]; then $(PIP_PATH) install $(patsubst %,"%",$(3)) --target .; fi; \
	rm ../$(2); \
	zip -r ../$(2) *; \
	cd ..; \
	rm -rf ./$(BUILD_DIR)

update-function = \
	$(AWS_CLI_PATH) lambda update-function-code \
		--function-name $(call get-property,$1,FunctionName) \
		--zip-file fileb://$(2) \
		$(if $(AWS_PROFILE),--profile $(AWS_PROFILE),)

create-function = \
	$(AWS_CLI_PATH) lambda create-function \
		--function-name $(call get-property,$1,FunctionName) \
		--zip-file fileb://$(2) \
		--runtime python3.7 \
		--role $(call execution-role,$(call get-property,$1,ExecutionRole)) \
		--timeout $(call timeout,$(call get-property,$1,Timeout)) \
		--handle function.lambda_handler \
		$(if $(AWS_PROFILE),--profile $(AWS_PROFILE),)

get-property = $(shell sed -nEe 's/^.*\#[[:blank:]]*@$(2):[[:blank:]]*(.*)$$/\1/p' $(1))
timeout = $(if $1,$1,180)
execution-role = arn:aws:iam::$(shell $(AWS_CLI_PATH) sts get-caller-identity $(if $(AWS_PROFILE),--profile $(AWS_PROFILE),) --output text --query 'Account'):role/$(if $1,$1,basic-lambda-role)