#!/bin/bash

unset ARCH
sudo update-alternatives --auto cc
sudo update-alternatives --auto gcc
sudo update-alternatives --auto ld
if [ -d /lib/modules/$(uname -r)/build.bak ]; then
    cp -dR /lib/modules/$(uname -r)/build.bak /lib/modules/$(uname -r)/build
fi
if [ -d /lib/modules/$(uname -r)/source.bak ]; then
    cp -dR /lib/modules/$(uname -r)/source.bak /lib/modules/$(uname -r)/source
fi
