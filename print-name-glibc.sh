cat template/glibc | sed 's/glibc-name/'$1'/g' | sed 's/glibc-version/'$2'/g' > appdir_glibc/DEBIAN/control
