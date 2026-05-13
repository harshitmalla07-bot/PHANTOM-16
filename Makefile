# PHANTOM-16 simulation Makefile
# Usage:
#   make sim MODULE=blinky    -> simulate tb/unit/tb_blinky.v
#   make wave MODULE=blinky   -> open the resulting waveform
#   make clean                -> remove sim artifacts

MODULE ?= blinky
SIM_DIR := sim
TB      := tb/unit/tb_$(MODULE).v
RTL     := $(shell find rtl -name '*.v')
OUT     := $(SIM_DIR)/$(MODULE).out
VCD     := $(SIM_DIR)/$(MODULE).vcd

.PHONY: sim wave clean

sim:
	mkdir -p $(SIM_DIR)
	iverilog -o $(OUT) $(TB) $(RTL)
	vvp $(OUT)

wave:
	gtkwave $(VCD) &

clean:
	rm -rf $(SIM_DIR)/*.out $(SIM_DIR)/*.vcd

