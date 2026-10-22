.PHONY: test check format

test:
	NVIM_LOG_FILE="$${TMPDIR:-/tmp}/zenon-test.log" nvim --headless -u NONE -i NONE -n --cmd 'set columns=240 lines=60' -c 'lua dofile("tests/run.lua")'

check:
	stylua --check lua plugin tests

format:
	stylua lua plugin tests
