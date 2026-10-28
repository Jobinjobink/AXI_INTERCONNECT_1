PYTHON ?= python3
TOOL_ARGS ?=
.PHONY: test compile synth soc audit all package

test compile synth soc audit all:
	$(PYTHON) scripts/run.py $@ $(TOOL_ARGS)

package:
	$(PYTHON) scripts/package.py --output ../axi4_4x4_crossbar_corrected.zip
