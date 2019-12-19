apt install git wget ca-certificates

mkdir /usr/local/share/ca-certificates/cacert.org
wget -P /usr/local/share/ca-certificates/cacert.org http://www.cacert.org/certs/root.crt http://www.cacert.org/certs/class3.crt
update-ca-certificates

dpkg --add-architecture i386
apt update

git clone https://github.com/Molytho/wine-lol-debian.git wine-lol --depth 1

cd wine-lol

./install-dependencies.sh
./wine-lol.sh
