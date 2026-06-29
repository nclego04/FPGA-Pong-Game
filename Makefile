# FPGA Pong -- simulation convenience targets.
#
# Thin wrapper around sim/run_tests.sh (the runner is the single source of
# truth so `make test` and CI behave identically). Requires Icarus Verilog
# (iverilog/vvp) on PATH.

.PHONY: test clean

# Compile and run every self-checking testbench; non-zero exit on any failure.
test:
	@bash sim/run_tests.sh

# Remove simulation build artifacts.
clean:
	@rm -rf build
