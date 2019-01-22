#!/bin/sh

ICTHOME="/home/ict"
ICTDIR="omega-ict"

if [ "$(id -u)" != "0" ]; then
	echo "Please run as root or sudo ./$0 RELEASE [NODENAME]."
	exit 1
fi
### insert webupd8team repos
echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" >> /etc/apt/sources.list.d/weupd8team.list
echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu xenial main" >> /etc/apt/sources.list.d/weupd8team.list
apt-key adv --no-tty --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886


PKGMANAGER=apt-get
	${PKGMANAGER} update -y
	${PKGMANAGER} upgrade -y
  ${PKGMANAGER} install -y curl wget unzip nano gnupg2 screen oracle-java8-installer



if [ "$1" = "RELEASE" ]; then
	cd ${ICTHOME}/${ICTDIR}
	VERSION=`curl --silent "https://api.github.com/repos/${GITREPO}/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	mkdir ict
	cd ict
	rm -f *.jar
	wget -c https://github.com/iotaledger/ict/releases/download/${VERSION}/ict-${VERSION}.jar
	VERSION="-${VERSION}"
	echo "### Done downloading ICT$VERSION"

	cd ${ICTHOME}/${ICTDIR}
	REPORT_IXI_VERSION=`curl --silent "https://api.github.com/repos/trifel/Report.ixi/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	mkdir Report.ixi
	cd Report.ixi
	rm -f *.jar *.zip
	wget -c https://github.com/trifel/Report.ixi/releases/download/${REPORT_IXI_VERSION}/report.ixi-${REPORT_IXI_VERSION}.jar
	REPORT_IXI_VERSION="-${REPORT_IXI_VERSION}"
	echo "### Done downloading Report.ixi$REPORT_IXI_VERSION"

	cd ${ICTHOME}/${ICTDIR}
	CHAT_IXI_VERSION=`curl --silent "https://api.github.com/repos/iotaledger/chat.ixi/releases" | grep '"tag_name":' |head -1 | sed -E 's/.*"([^"]+)".*/\1/'`
	mkdir chat.ixi
	cd chat.ixi
	rm -f *.jar *.zip
	wget -c https://github.com/iotaledger/chat.ixi/releases/download/${CHAT_IXI_VERSION}/chat.ixi-${CHAT_IXI_VERSION}.jar
	CHAT_IXI_VERSION="-${CHAT_IXI_VERSION}"
	echo "### Done downloading Chat.ixi$CHAT_IXI_VERSION"
fi

echo "### Preparing directories, run script, and configs"

mkdir -p ${ICTHOME}/config

echo "### Creating default ict.cfg template"
cd ${ICTHOME}/${ICTDIR}
rm -f ict.cfg
java -jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar --config-create &
last_pid=$!
while [ ! -f ict.cfg ] ; do sleep 1 ; done
sleep 1
kill -KILL $last_pid 2>/dev/null 1>/dev/null
rm -rf web

if [ ! -f ${ICTHOME}/config/ict.cfg ]; then
	if [ -f ${ICTHOME}/config/ict.properties ]; then
		echo "### Importing from old ict.properties"
		host=`sed -ne 's/^host\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		port=`sed -ne 's/^port\s*=\s*//gp' ${ICTHOME}/config/ict.properties`
		neighbors=`sed -ne 's/^neighbor\(A\|B\|C\)\(Host\|Port\)\s*=\s*//gp' ${ICTHOME}/config/ict.properties | sed ':a;N;$!ba;s/\n/:/g;s/:\([^:]*\):/:\1,/g'`
		sed -i "s/^host=.*$/host=$host/;s/^port=.*$/port=$port/;s/^neighbors=.*$/neighbors=$neighbors/" ict.cfg
	fi
else
	echo "### Importing from existing ict.cfg"
	grep -v "^#" ${ICTHOME}/config/ict.cfg | while IFS="=" read -r varname value ; do
		echo "### Setting config $varname to ${value}"
		sed -i "s/^$varname=.*$/$varname=$value/" ict.cfg
		cp -f ict.cfg ${ICTHOME}/config/ict.cfg
	done
fi

if [ /bin/true ]; then
	echo "### Adapting run script and configs for IXIs"
	cat <<EOF > ${ICTHOME}/run-ict.sh
#!/bin/sh
cd ${ICTHOME}/${ICTDIR}
java -jar ${ICTHOME}/${ICTDIR}/ict/ict${VERSION}.jar -c ${ICTHOME}/config/ict.cfg &
ict_pid=\$!
echo \$ict_pid > ict.pid
EOF
	cat <<EOF > ${ICTHOME}/stop-ict.sh
#!/bin/sh
cd ${ICTHOME}/${ICTDIR}
kill \$(cat ${ICTHOME}/${ICTDIR}/ict.pid)
EOF
	chmod a+x ${ICTHOME}/run-ict.sh ${ICTHOME}/stop-ict.sh
	cd ${ICTHOME}/${ICTDIR}
	cp -f ${ICTHOME}/${ICTDIR}/Report.ixi/report.ixi${REPORT_IXI_VERSION}.jar ${ICTHOME}/${ICTDIR}/modules/report.ixi${REPORT_IXI_VERSION}.jar
	echo "### Creating default report.ixi.cfg template"
	echo "name=nick (ict-0)" > report.ixi.cfg
	echo "neighbors=127.0.0.1\:1338" >> report.ixi.cfg
	echo "reportPort=1338" >> report.ixi.cfg
	echo "### Setting config neighbors in report.ixi.cfg"
	neighbors=`sed -ne 's/:[[:digit:]]\+/:1338/g;s/^neighbors\s*=\s*//gp' ict.cfg`
	sed -i "s/^neighbors=.*$/neighbors=$neighbors/" report.ixi.cfg

	if [ -f ${ICTHOME}/config/report.ixi.cfg -a ! -h ${ICTHOME}/config/report.ixi.cfg ]; then
		echo "### Importing from old report.ixi.cfg"
		grep -v "^#" ${ICTHOME}/config/report.ixi.cfg | while IFS="=" read -r varname value ; do
			echo "### Setting config $varname to ${value} in report.ixi.cfg"
			sed -i "s/^$varname=.*$/$varname=$value/" report.ixi.cfg
		done
		if [ `grep -c "^neighbor[A|B|C][Host|Port]" report.ixi.cfg` -gt 0 ] && [ `grep -c "^neighbors=[^[:space:]+]" report.ixi.cfg` -eq 0 ]  ; then
			neighbors=`sed -ne 's/^neighbor\(A\|B\|C\)\(Host\|Port\)\s*=\s*//gp' ../config/report.ixi.cfg | sed ':a;N;$!ba;s/\n/:/g;s/:\([^:]*\):/:\1,/g'`
			echo "### Converting neighbor?Host syntax to $neighbors"
			sed -i "s/^neighbors=.*$/neighbors=$neighbors/" report.ixi.cfg
		fi
		sed -i "/^neighbor[A|B|C][Host|Port]/d" report.ixi.cfg
		rm -f ${ICTHOME}/config/report.ixi.cfg
	fi
	if [ -f ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg ]; then
		cp -f ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg.last
		echo "### Importing from existing report.ixi.cfg"
		grep -v "^#" ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg | while IFS="=" read -r varname value ; do
			echo "### Setting config $varname to ${value} in report.ixi.cfg"
			sed -i "s/^$varname=.*$/$varname=$value/" report.ixi.cfg
		done
	fi
	if [ -n "$2" ] ; then
		echo "### Setting nodename of the node to $2"
		sed -i "s/^name=.*$/name=$2/" report.ixi.cfg
	fi
	if [ `grep -Ec "^name=[^()]+ \(ict-[[:digit:]]+\)$" report.ixi.cfg` -eq 0 ] ; then
		nodename=""
		while [ `echo "$nodename" | grep -Ec "^[^()]+ \(ict-[[:digit:]]+\)$"` -eq 0 ] ; do
			echo "### Please give your node an individual name. Follow the naming convention: <name> (ict-<number>)"
			read -r nodename
		done
		sed -i "s/^name=.*$/name=$nodename/" report.ixi.cfg
	fi

	mkdir -p ${ICTHOME}/${ICTDIR}/modules/report.ixi
	cp -f report.ixi.cfg ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg
	rm -f ${ICTHOME}/config/report.ixi.cfg
	ln -s ${ICTHOME}/${ICTDIR}/modules/report.ixi/report.ixi.cfg ${ICTHOME}/config/
#	sed -i "s/^ixi_enabled=.*$/ixi_enabled=true/" ict.cfg
	rm -f ${ICTHOME}/${ICTDIR}/modules/report.ixi*jar
	cp -f ${ICTHOME}/${ICTDIR}/Report.ixi/report.ixi${REPORT_IXI_VERSION}.jar ${ICTHOME}/${ICTDIR}/modules/report.ixi${REPORT_IXI_VERSION}.jar

	if [ -f ${ICTHOME}/config/chat.ixi.cfg -a ! -h ${ICTHOME}/config/chat.ixi.cfg ] ; then
		CHATUSER=`sed -ne "s/^username=\(.*\)$/\1/gp" ${ICTHOME}/config/chat.ixi.cfg`
		RANDOMPASS=`sed -ne "s/^password=\(.*\)$/\1/gp" ${ICTHOME}/config/chat.ixi.cfg`
	elif [ -f ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg ] ; then
		CHATUSER=`sed -ne "s/^username=\(.*\)$/\1/gp" ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg`
		RANDOMPASS=`sed -ne "s/^password=\(.*\)$/\1/gp" ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg`
		ln -s ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg ${ICTHOME}/config/
	else
		mkdir -p ${ICTHOME}/${ICTDIR}/modules/chat-config
		CHATUSER=`sed -ne "s/^name=\(.*\) .*$/\1/p" report.ixi.cfg`
		RANDOMPASS=`< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12`
		#read -e -p "Enter a password for Chat.ixi API:" -i "${CHATUSER}" CHATUSER
		#read -e -p "Enter a password for Chat.ixi API:" -i "${RANDOMPASS}" RANDOMPASS
		echo "username=$CHATUSER" > ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg
		echo "password=$RANDOMPASS" >> ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg
		ln -s ${ICTHOME}/${ICTDIR}/modules/chat-config/chat.cfg ${ICTHOME}/config/
	fi
	rm -f ${ICTHOME}/config/chat.ixi.cfg
	rm -rf ${ICTHOME}/${ICTDIR}/modules/chat.ixi*
	cp -f ${ICTHOME}/${ICTDIR}/chat.ixi/chat.ixi${CHAT_IXI_VERSION}.jar ${ICTHOME}/${ICTDIR}/modules/chat.ixi${CHAT_IXI_VERSION}.jar

	if [ "$1" = "EXPERIMENTAL" ]; then
		if [ ! -f ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi/zeromq.ixi.cfg ] ; then
			mkdir -p ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi
			echo "ZMQPORT=5560" > ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi/zeromq.ixi.cfg
			rm -f ${ICTHOME}/config/zeromq.ixi.cfg
			ln -s ${ICTHOME}/${ICTDIR}/modules/zeromq.ixi/zeromq.ixi.cfg ${ICTHOME}/config/
		fi
		rm -f ${ICTHOME}/${ICTDIR}/modules/ixi-zeromq*jar
		cp -f ${ICTHOME}/${ICTDIR}/iota-ixi-zeromq/ixi-zeromq/target/ixi-zeromq-jar-with-dependencies.jar ${ICTHOME}/${ICTDIR}/modules/
	fi
fi

echo "### Writing new configs"
cd ${ICTHOME}/${ICTDIR}
cp -f ${ICTHOME}/config/ict.cfg ${ICTHOME}/config/ict.cfg.last
cp -f ict.cfg ${ICTHOME}/config/ict.cfg
chown -R ict ${ICTHOME}/config ${ICTHOME}/${ICTDIR}

echo "### Deleting old directories and temporary files"
cd ${ICTHOME}/${ICTDIR}
rm -rf *ctx* *.key *.cfg logs ixi channels.txt contacts.txt ${ICTHOME}/config/*.properties ${ICTHOME}/config/*.key ${ICTHOME}/config/*.txt

echo "### NOT INSTALLED AS SERVICE ON ANDROID. STARTING IN FORGROUND."
	cd ${ICTHOME}/${ICTDIR}
	${ICTHOME}/stop-ict.sh
	sudo ${ICTHOME}/run-ict.sh &
