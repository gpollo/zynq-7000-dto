# Zynq-7000 & Device Tree Overlay

The [Zynq-7000](https://www.xilinx.com/products/silicon-devices/soc/zynq-7000.html) chips
are versatile chips from [Xilinx](https://www.xilinx.com/) that combine both ARM cores and
an FPGA fabric.

This repository presents an example on how to update the FPGA bitstream in Linux (at runtime)
and load a [device tree overlay](https://www.kernel.org/doc/html/latest/devicetree/overlay-notes.html)
in order to expose AXI peripherals of the new bitstream.

## Requirements

To run the example, you need a [minized](https://www.avnet.com/wps/portal/us/products/avnet-boards/avnet-board-families/minized/)
board from Avnet. The example uses Vivado 2021.1 and Petalinux 2021.1.

## Vivado Setup

The Vivado project contains two block designs.
* The first one, named `toplevel_basic`, is a block design with a
  [Zynq-7000 Processing System](https://www.xilinx.com/products/intellectual-property/processing_system7.html),
  an [AXI Interconnect](https://www.xilinx.com/products/intellectual-property/axi_interconnect.html) and an
  [AXI GPIO](https://www.xilinx.com/products/intellectual-property/axi_gpio.html) blocks.
    * From testing, the AXI GPIO is needed in order to expose device tree paths to our overlay.
* The second one, named `toplevel_axi`, is a block design with a
  [Zynq-7000 Processing System](https://www.xilinx.com/products/intellectual-property/processing_system7.html),
  an [AXI Interconnect](https://www.xilinx.com/products/intellectual-property/axi_interconnect.html) and
  custom AXI blocks.

The goal is to create a system with `toplevel_basic` block design, then program the bitstream of `toplevel_axi`
and controls the custom AXI blocks without rebooting the system.

### Building the Bitstreams

To create the bitstreams, you first need to re-create the Vivado project from a script.

1. Open Vivado 2021.1 and run these commands into the TCL console to re-create the project.
    ```tcl
    $ cd path/to/this/repository/
    $ source setup_project.tcl
    ```
2. Right-click `toplevel_basic_wrapper` → *Set as Top*.
3. Then click on *Generate Bitstream*.
4. *File* → *Export* → *Export Hardware...* and make sure to include bitstream.
    * It should've created a file `vivado/toplevel_basic_wrapper.xsa`.
5. Right-click `toplevel_axi_wrapper` → *Set as Top*.
6. Then click on *Generate Bitstream*.
7. Generate the `*.bin` file from the TCL console.
    ```tcl
    $ write_cfgmem -force -format bin -interface smapx32 -disablebitswap -loadbit \
        "up 0 vivado/vivado.runs/impl_1/toplevel_axi_wrapper.bit" \
        vivado/toplevel_axi_wrapper.bin
    ```
    * It should've created a file `vivado/toplevel_axi_wrapper.bin`.

## Petalinux Setup

The Petalinux project is pretty simple and only configured to boot from JTAG.

You can build and boot the project with the following commands.

```bash
$ source /opt/Xilinx/petalinux/settings.sh

$ petalinux-build
$ petalinux-package --prebuilt --force
$ petalinux-boot --jtag --prebuilt 3 --fpga
```

*The command `petalinux-build` may fails because, by default, Petalinux assumes we are targeting
a dual-core system, but the Minized only as a single-core Zynq-7000S. To fix, we need to edit
`components/plnx_workspace/device-tree/device-tree/zynq-7000.dtsi` (generated at build time)
to remove missing references and re-run `petalinux-build`.*

For reference, the project was configured with the following commands.

```bash
$ source /opt/Xilinx/petalinux/settings.sh

$ petalinux-create -t project -n petalinux --template zynq
$ cd petalinux/

$ petalinux-config --get-hw-description ../vivado/toplevel_basic_wrapper.xsa

$ petalinux-config -c rootfs
# Filesystem Packages →
#   console →
#     utils →
#       vim →
#         [*] vim
#   misc →
#     coreutils →
#       [*] coreutils
#     packagegroup-core-buildessential →
#       [*] packagegroup-core-buildessential

$ petalinux-config -c kernel
# Device Drivers →
#   <*> Userspace I/O drovers →
#     <M> Userspace I/O platform driver with generic IRQ handling
#     <*> Xilinx AXI Performance Monitor driver

$ vim project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi
# Custom device-tree configuration (enable generic-uio and USB controller).
```

## Update Bitstream and Run Test

Once the system is booted, open its serial terminal (e.g. `/dev/ttyUSB1`).

```bash
$ screen /dev/ttyUSB1 115200
```

You can have a look at the peripherals exposed from the programmable logic (PL), the FPGA.
You should be able to see the AXI GPIO device.

```bash
$ ls /sys/devices/soc0/amba_pl/
41200000.gpio/   ...
```

Use a USB stick to transfer the files `source/test-axi-int.*` and `vivado/toplevel_axi_wrapper.bin`.

```bash
$ cd /run/media/sda1/
$ ls
test-ax-int.dts  test-axi-int.c  toplevel_axi_wrapper.bin
```

To program the new bitstream onto the FPGA, execute the following commands.

```bash
$ echo 0 > /sys/class/fpga_manager/fpga0/flags
$ mkdir -p /lib/firmware/
$ cp toplevel_axi_wrapper.bin /lib/firmware/toplevel_axi_wrapper.bin
$ echo toplevel_axi_wrapper.bin > /sys/class/fpga_manager/fpga0/firmware
```

To compile and load the device tree overlay, execute the following commands.

```bash
$ dtc -I dts -O dtb test-ax-int.dts -o test-ax-int.dtb
$ mkdir /sys/kernel/config/device-tree/overlays/axi-int
$ cat test-ax-int.dtb > /sys/kernel/config/device-tree/overlays/axi-int/dtbo
```

You should now see the following peripherals. It is important to note that the AXI GPIO
is still there even thought it is not present in the `toplevel_axi` block design. That
is because we haven't removed the old node with our device tree overlay.

```bash
$ ls /sys/devices/soc0/amba_pl/
41200000.gpio  43c00000.axi_int_test  43c10000.axi_int_test  ...
```

You should also see two [userspace I/O](https://www.kernel.org/doc/html/v4.12/driver-api/uio-howto.html) (UIO) devices.

```bash
$ ls /dev/uio*
/dev/uio0  /dev/uio1
```

Compile and run the test program to control these two UIOs. This program will writes to some registers on
the custom AXI peripherals and wait for their interrupts (CTRL+C to shutdown).

```bash
$ gcc -Wall test-axi-int.c -o test-axi-int -lpthread
$ ./test-axi-int
[0647] opened /dev/uio0
[0648] opened /dev/uio1
[0647] CONTROL=1 COUNTER1=0x00000A1C COUNTER2=0x00000001
[0648] CONTROL=1 COUNTER1=0x000009BA COUNTER2=0x00000001
[0647] CONTROL=1 COUNTER1=0x000009C2 COUNTER2=0x00000002
[0648] CONTROL=1 COUNTER1=0x0000094C COUNTER2=0x00000002
[0647] CONTROL=1 COUNTER1=0x00000928 COUNTER2=0x00000003
[0648] CONTROL=1 COUNTER1=0x000008C5 COUNTER2=0x00000003
...
```

You can remove the device tree overlay with the following command. If you generated the
`toplevel_basic_wrapper.bin` file, you can re-program the old bitstream.

```bash
$ rmdir /sys/kernel/config/device-tree/overlays/axi-int

$ ls /dev/uio*
<nothing>

$ ls /sys/devices/soc0/amba_pl/
41200000.gpio/   ...
```