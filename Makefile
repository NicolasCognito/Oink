.PHONY: test test-gtest spec clean

# Default test output file (can override: make test OUT=path)
OUT ?= scripts/test-results.txt

test:
	@bash scripts/test --out $(OUT) spec/*.lua

test-gtest:
	@bash scripts/test --gtest --out $(OUT) spec/*.lua

# Run a single spec: make spec FILE=spec/move_spec.lua
spec:
	@test -n "$(FILE)" || (echo "Usage: make spec FILE=spec/<name>_spec.lua"; exit 1)
	@bash scripts/test --out $(OUT) $(FILE)

clean:
	@rm -f scripts/test-results.txt
	@echo "Cleaned test artifacts."

