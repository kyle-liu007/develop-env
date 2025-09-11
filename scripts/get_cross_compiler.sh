 #!/bin/bash

arch=$1

echo ${arch}-linux-gnu- | sed -e 's/x86/x86_64-buildroot/'\
                              -e 's/loongarch/loongarch64/'\
                              -e 's/arm64/aarch64-buildroot/'\
                              -e 's/riscv/riscv64-buildroot/'
