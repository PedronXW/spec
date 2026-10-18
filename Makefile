.PHONY: test lint smoke smoke-parallel install

lint:
	bash -n bin/specs lib/specs.sh lib/commands.sh
	@echo "lint OK"

smoke:
	bash tests/smoke.sh

smoke-parallel:
	bash tests/smoke-parallel.sh

test: lint smoke smoke-parallel
	@echo "ALL GREEN"

install: lint
	./install.sh