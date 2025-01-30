#!/bin/sh
# Script to download, compile and install the OS cross compiling tools
# Dependencies (script): coreutils, curl, make
# Dependencies (build): gcc, g++, bison, flex, gmp, mpfr, mpc, texinfo

# !* Modify parameters here *!
GNU_MIRROR="https://ftp.gnu.org"
BINUTILS_VERSION="2.43.1"
GCC_VERSION="14.2.0"


# TODO: missing error handling for curl, configure and make

echo "x86_64-elf Cross Tools installer"
echo -e "--------------------------------\n"
cd "$(dirname "$0")"    # set cwd

if [ ! -d "cross" ]; then
    mkdir cross
elif [ ! -z "$(ls -A cross)" ]; then
    if [ -f "./cross/bin/x86_64-elf-gcc" ]; then
        echo "Cross Tools seem already installed"
    fi
    echo "Please empty ./cross folder before (re)installing."
    exit 1
fi


cd ./cross
echo "Downloading - BinUtils $BINUTILS_VERSION"
curl "$GNU_MIRROR/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz" -o binutils_source.tar.gz
tar -xf binutils_source.tar.gz
echo "Downloading - GCC $GCC_VERSION"
curl "$GNU_MIRROR/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz" -o gcc_source.tar.gz
tar -xf gcc_source.tar.gz


PREFIX=`realpath .`
export PATH="$PREFIX/bin:$PATH"

mkdir binutils_build
cd binutils_build
echo -e "\nConfiguring - BinUtils $BINUTILS_VERSION"
../binutils-$BINUTILS_VERSION/configure --target=x86_64-elf --prefix="$PREFIX" --with-sysroot --disable-nls
echo -e "\nCompiling - BinUtils $BINUTILS_VERSION"
make -j8
echo -e "\nInstalling - BinUtils $BINUTILS_VERSION"
make install
cd ..

mkdir gcc_build
cd gcc_build
echo -e "\nConfiguring - GCC $GCC_VERSION"
../gcc-$GCC_VERSION/configure --target=x86_64-elf --prefix="$PREFIX" --disable-nls --enable-languages=c,c++ --without-headers --disable-hosted-libstdcxx
echo -e "\nCompiling - GCC $GCC_VERSION"
make all-gcc -j8
make all-target-libgcc CFLAGS_FOR_TARGET="-g -O2 -mno-red-zone" -j8
make all-target-libstdc++-v3 -j8
echo -e "\nInstalling - GCC $GCC_VERSION"
make install-gcc
make install-target-libgcc
make install-target-libstdc++-v3
cd ..


echo -e "\nCleaning up..."
rm -r *tar.gz
rm -rf binutils-$BINUTILS_VERSION binutils_build
rm -rf gcc-$GCC_VERSION gcc_build
echo "Done. Have a nice day!"