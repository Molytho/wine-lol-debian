#!/bin/bash
version=9.24-1

PARALLEL=4

glibc_src=https://ftp.gnu.org/gnu/glibc/glibc-2.30.tar.xz
wine_src=https://dl.winehq.org/wine/source/4.x/wine-4.20.tar.xz
wine_staging_src=https://github.com/wine-staging/wine-staging/archive/v4.20.tar.gz

glibc_md5sum=2b1dbdf27b28620752956c061d62f60c
wine_md5sum=8cc2c2df281ef89217573ca228bc7ba7
wine_staging_md5sum=792ad8b24dfa26200b5ab5be7168fbbc

function die
{
	echo $1
	exit -1
}

function package_missing
{
	die "Package missing: $1"
}

function config_wine
{
    export CC="gcc -m32"
    export CXX="g++ -m32"
    export CFLAGS="-O3"
    
    _RPATH="-rpath=/opt/wine-lol/lib32"
    _LINKER="--dynamic-linker=/opt/wine-lol/lib32/ld-linux.so.2"

    export LDFLAGS="-Wl,$_RPATH,$_LINKER -L/opt/wine-lol/lib32"

    ../../src/wine-src/configure \
        --prefix=/opt/wine-lol/ \
        --libdir=/opt/wine-lol/lib32

    make depend LDRPATH_INSTALL="-Wl,$_RPATH,$_LINKER"
}

function config_glibc
{
    local _configure_flags=(
      --prefix=/opt/wine-lol
      --with-headers=/usr/include
      --with-bugurl=https://bugs.archlinux.org/
      --enable-add-ons
      --enable-bind-now
      --enable-lock-elision
      --enable-stack-protector=strong
      --enable-stackguard-randomization
      --disable-profile
      --disable-werror
    )

    export CC="gcc -m32 -mstackrealign"
    export CXX="g++ -m32 -mstackrealign"

    echo "slibdir=/opt/wine-lol/lib32" >> configparms
    echo "rtlddir=/opt/wine-lol/lib32" >> configparms
    echo "sbindir=/opt/wine-lol/bin" >> configparms
    echo "rootsbindir=/opt/wine-lol/bin" >> configparms

    export CFLAGS="-O3"

    ../../src/glibc-src/configure \
      --host=i686-pc-linux-gnu \
      --libdir=/opt/wine-lol/lib32 \
      --libexecdir=/opt/wine-lol/lib32 \
      ${_configure_flags[@]}
}

wget --help > /dev/null
if [ $? != 0 ]
	then package_missing "wget"
fi
tar --help > /dev/null
if [ $? != 0 ]
	then package_missing "tar"
fi
md5sum --help > /dev/null
if [ $? != 0 ]
	then package_missing "md5sum"
fi
autoreconf --help > /dev/null
if [ $? != 0 ]
	then package_missing "autoconf"
fi
automake --help > /dev/null
if [ $? != 0 ]
	then package_missing "automake"
fi

if [ ! -d src ]
	then mkdir src
fi
pushd src

if [ ! -f src_wine.tar.xz ]
	then wget -O src_wine.tar.xz $wine_src
fi
if [ ! -f src_wine_staging.tar.gz ]
	then wget -O src_wine_staging.tar.gz $wine_staging_src
fi
if [ ! -f src_glibc.tar.xz ]
	then wget -O src_glibc.tar.xz $glibc_src
fi

echo "$glibc_md5sum  src_glibc.tar.xz" > sums
md5sum -c sums
if [ $? != 0 ]
	then die "integrity error: glibc"
fi

echo "$wine_staging_md5sum  src_wine_staging.tar.gz" > sums
md5sum -c sums
if [ $? != 0 ]
	then die "integrity error: wine_staging"
fi

echo "$wine_md5sum  src_wine.tar.xz" > sums
md5sum -c sums
if [ $? != 0 ]
	then die "integrity error: wine"
fi

rm sums

if [ -d wine-4.20 ]
	then rm -r wine-4.20
fi
if [ -d glibc-2.30 ]
	then rm -r glibc-2.30
fi
if [ -d wine-staging-4.20 ]
	then rm -r wine-staging-4.20
fi
if [ -f wine-src ]
    then rm wine-src
fi
if [ -f glibc-src ]
    then rm glibc-src
fi    

tar -xf src_glibc.tar.xz
tar -xf src_wine.tar.xz
tar -xf src_wine_staging.tar.gz
ln -s glibc-2.30 glibc-src
ln -s wine-4.20 wine-src

pushd wine-staging-4.20/patches
./patchinstall.sh DESTDIR=../../wine-4.20 --all
popd

pushd wine-4.20
find ../../patches-wine -name "*.patch" -exec patch -p1 -i {} \;
popd

pushd glibc-2.30
find ../../patches-glibc -name "*.patch" -exec patch -p1 -i {} \;
popd
popd

if [ -d build ]
    then rm -r build
fi
mkdir build

pushd build
mkdir wine
mkdir glibc

pushd glibc

config_glibc
make -j$PARALLEL || die "glibc failed"
make install_root="$PWD/../../appdir_glibc" install -j$PARALLEL || die "glibc failed"

popd

pushd ..

./print-name-glibc.sh wine-lol-glibc-dev $version
dpkg-deb --build appdir_glibc
dpkg -i appdir_glibc.deb|| die "could not install package"
mv appdir_glibc.deb wine-lol-glibc-dev_$version.deb

popd

pushd wine

config_wine
export LD_LIBRARY_PATH=/opt/wine-lol/lib32
make -j$PARALLEL || die "wine failed"
make prefix="$PWD/../../appdir_wine/opt/wine-lol" \
    libdir="$PWD/../../appdir_wine/opt/wine-lol/lib32" \
    dlldir="$PWD/../../appdir_wine/opt/wine-lol/lib32/wine" install -j$PARALLEL || die "wine failed"

popd

popd

dpkg -r wine-lol-glibc-dev

find appdir_wine/ -type f -exec file {} \; | grep "not stripped" | sed 's/:.*//' | while read i; do strip $i; done
find appdir_glibc/ -type f -exec file {} \; | grep "not stripped" | sed 's/:.*//' | while read i; do strip $i; done

./print-name-glibc.sh wine-lol-glibc $version
dpkg-deb --build appdir_glibc
mv appdir_glibc.deb wine-lol-glibc_$version.deb
./print-name-wine.sh wine-lol $version
dpkg-deb --build appdir_wine
mv appdir_wine.deb wine-lol_$version.deb

exit 0

