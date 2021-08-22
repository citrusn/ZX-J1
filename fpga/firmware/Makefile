all: j1 j1.bin j1.hex

sim: j1.hex
	C:\altera\iverilog\bin\iverilog -o j1.sim fpga/src/j1.v fpga/src/j1-tb.v 
	C:\altera\iverilog\bin\vvp j1.sim
# call C:\altera\iverilog\gtkwave\bin\gtkwave.exe j1.vcd

ula: picture.hex
	C:\altera\iverilog\bin\iverilog -o ula.sim fpga/src/ula.v fpga/src/ula-tb.v 
	C:\altera\iverilog\bin\vvp ula.sim
#  call C:\altera\iverilog\gtkwave\bin\gtkwave.exe ula.vcd

# -lwpcap
j1: j1.c
	gcc -o j1 j1.c 
	strip -s j1
j1.bin j1.hex: j1.4th
	C:\Progs\gforth7\gforth.exe	./j1.4th
run: all
	./j1
core: all
	./j1 core.4th
clean:
	rm -rf j1 j1.bin j1.hex
