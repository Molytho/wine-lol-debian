cat template/wine | sed 's/wine-name/'$1'/g' | sed 's/wine-version/'$2'/g' > appdir_wine/DEBIAN/control
