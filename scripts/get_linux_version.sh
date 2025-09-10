#!/bin/bash

if [ $1 = 4 ]; then
    linux_version="4.19.305"
elif [ $1 = 5 ]; then
    linux_version="5.15.147"
elif [ $1 = 6 ]; then
    linux_version="6.6.17"
elif [ $1 = 2 ]; then
	linux_version="2.6.23"
fi

echo ${linux_version}
