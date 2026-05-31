# FPGA Hardware IDS — Hardware Project

FPGA-Accelerated Network Intrusion Detection System  
Board: MicroPhase Z7-Lite (XC7Z020-1CLG400C)  
Tool: Vivado ML 2025.2

## How to Rebuild This Project

### 1. Clone the repo
git clone <repo-url>
cd ids_hw

### 2. Create a new Vivado project
- Open Vivado 2025.2
- Create Project → RTL Project → Part: xc7z020clg400-1L
- Add all .vhd files from src/ as design sources
- Add ids_hw.xdc as constraint

### 3. Recreate the block design
In the Vivado Tcl console (bottom panel), run:
source ids_system.tcl

This recreates the Zynq PS + AXI DMA block design automatically.

### 4. Generate wrapper
- Right-click ids_system.bd → Generate Output Products
- Right-click ids_system.bd → Create HDL Wrapper

### 5. Set top level
- Right-click ids_hw_top in Sources → Set as Top

### 6. Generate bitstream
- Run Synthesis → Implementation → Generate Bitstream

## Pin Assignments (Z7-Lite)
| Signal       | Pin | Function        |
|-------------|-----|-----------------|
| clk         | N18 | 50 MHz PL clock |
| rst_n       | P16 | PL_KEY1 reset   |
| led_alert_n | P15 | Alert LED       |
| led_active_n| U12 | Activity LED    |

## IDS Rules
- 12 IPv4 rules (R1-R12)
- 5 TCP rules (T1-T5)  
- 9 UDP rules (U1-U9)
- Total: 26 rules verified