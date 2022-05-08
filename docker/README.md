# Petalinux Docker Image

Petalinux isn't very stable or won't work properly unless you are using one of their
supported operating systems.

By using this Docker image, Petalinux should work pretty well on any Linux based machine.

## Requirements

Before building the image, you need to download Petalinux 2021.1 installer
located [here](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/embedded-design-tools.html).

The downloaded file should be placed in this directory and named
`petalinux-v2021.1-final-installer.run`.

This has been tested on an installer with MD5 hash `a44e1ff42ef3eedc322a72d790b1931d`.

## Building

```bash
$ docker build . -t petalinux:2021.1
```

## Running

```
$ cd path/to/petalinux/project/
$ docker run -it --rm -v $PWD:/petalinux petalinux:2021.1
```