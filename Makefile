# tools
#
AWS_CLI	?= /usr/bin/env aws
PIP		?= /usr/bin/env pip

# paths and files
#
TARGET_DIR	?= target
BUILD_DIR 	?= build
BUILD_LOG 	?= build.log

# target files
#
LAMBDAS = $(shell grep -lE '\#[[:blank:]]*@FunctionName:' *.py)
PACKAGES = $(LAMBDAS:%.py=$(TARGET_DIR)/%.zip)
RECEIPTS = $(LAMBDAS:%.py=$(TARGET_DIR)/%.receipt)

# build targets
#
default:
	@echo "Usage: make [command]"
	@echo "Available commands: detect-functions, build, update, create, clean"

detect-functions:
	@$(foreach file,$(LAMBDAS),echo $(file): $(call get-property,$(file),FunctionName))

build: $(PACKAGES)

update: $(RECEIPTS)

clean:
	@rm -rf $(TARGET_DIR)

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
	@out=`$(call update-function,$(call bundle-function-name,$<),$<)`; \
	if [ $$? -ne 0 ]; then \
		echo failed; \
		exit 1; \
	fi; \
	echo $$out > $@
	@echo ok

$(TARGET_DIR)/%.zip: %.py
	@echo "Found Lambda function in $<"
	@echo "Creating deployment bundle..."
	@$(call create-package,$<,$@); \
	if [ $$? -ne 0 ]; then \
		echo "Failed to create the package, see $(BUILD_LOG)"; \
		exit 1; \
	fi
	@echo "Success"

$(PACKAGES): | $(TARGET_DIR)

$(TARGET_DIR):
	@mkdir $(TARGET_DIR)

create-package = $(call do-create-package,$1,$2,$(call get-property,$1,Requires),$(call get-property,$1,Includes))
do-create-package = \
	if [[ ! -f "$(1)" ]]; then \
		echo "Function source file $(1) does not exist?"; \
		exit 1; \
	fi; \
	touch $(BUILD_LOG); \
	mkdir -p $(BUILD_DIR); \
	cd $(BUILD_DIR); \
	echo "[install]\nprefix=\n" > setup.cfg; \
	cp ../$(1) ./function.py; \
	if [[ "$(3)" != "" ]]; then \
		echo "  Installing packages..."; \
		$(foreach pkg,$(3),echo "    + $(pkg)"; $(PIP) install "$(pkg)" --target . >> ../$(BUILD_LOG) || exit 1 ;) \
	fi; \
	if [[ "$(4)" != "" ]]; then \
		echo "  Adding dependencies..."; \
		$(foreach file,$(4),echo "    + $(file)"; rsync --recursive --exclude __pycache__ "../$(file)" . || exit 1 ;) \
	fi; \
	if [[ -f "../$(2)" ]]; then rm ../$(2); fi; \
	echo "  Creating archive..."; \
	zip -r ../$(2) * >> ../$(BUILD_LOG); \
	cd ..; \
	rm -rf ./$(BUILD_DIR) ./$(BUILD_LOG)

update-function = $(call do-update-function,$1,$2,$(call get-property,$1,Region))
do-update-function = \
	$(AWS_CLI) lambda update-function-code \
		--function-name $(call get-property,$1,FunctionName) \
		--zip-file fileb://$(2) \
		$(if $(AWS_PROFILE),--profile "$(AWS_PROFILE)",) \
		$(if $3,--region "$3",)

create-function = $(call do-create-function,$1,$2,$(call get-property,$1,Region))
do-create-function = \
	$(AWS_CLI) lambda create-function \
		--function-name $(call get-property,$1,FunctionName) \
		--zip-file fileb://$(2) \
		--runtime python3.7 \
		--role $(call execution-role,$(call get-property,$1,ExecutionRole)) \
		--timeout $(call timeout,$(call get-property,$1,Timeout)) \
		--handle function.lambda_handler \
		$(if $(AWS_PROFILE),--profile "$(AWS_PROFILE)",) \
		$(if $3,--region "$3",)

get-property = $(shell sed -nEe 's/^.*\#[[:blank:]]*@$(2):[[:blank:]]*(.*)$$/\1/p' $(1))
timeout = $(if $1,$1,180)
execution-role = arn:aws:iam::$(shell $(AWS_CLI) sts get-caller-identity $(if $(AWS_PROFILE),--profile $(AWS_PROFILE),) --output text --query 'Account'):role/$(if $1,$1,basic-lambda-role)
bundle-function-name = $(1:$(TARGET_DIR)/%.zip=%.py)