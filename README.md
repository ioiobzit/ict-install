# ict-install
Scripts for installing IOTA ICT (current omegan version) on Debian GNU/Linux on Android.

This installation differs from https://github.com/phschaeff/ict-install by removing services scripts and options that are not usable with Debian GNU/Linux on Android.
No BUILD
NO Experimental

## RELEASE install
Run:
`sudo ./install-ict.sh RELEASE nodename`
to download and run the latest binary release from github.

nodename can be left blank.

It will:
* Install required dependencies (Oracle Java8 JDK) 
* Add an user "ict"
* Download and compile the omegas ICT code in /home/ict/omega-ict
* Generate a run script
* Import settings from old `ict.properties` (has to be located in `/home/ict/config/ict.properties`)
* Generate a systemd service
* Generate a cronjob restarting ICT every night
* Start the ICT service


Tested on:
* Debian GNU/Linux Userland for Android

## Troubleshooting Guide

Some common errors encountered when starting ict.

### UnknownHostException

This error is usually due to an invalid entry in the `ict.properties` file.
e.g. neighborCHost = ?.?.?.?
is not a valid hostname.

Make sure you only use valid hostnames or ip addresses.

Sometimes this error is caused by trailing white spaces in the hostname.

### BindException

Address already in use (Bind failed)
This error occurs when ICT is started while another process already is using the `port` specified in the `ict.properties` file.
Usually this may be another instance of ICT or IRI.

Check for processes running on port 14265 by running:
`sudo netstat -ntalpu | grep 14265`

### OutOfMemoryError

This error may occure after ICT has been running for some time.
While ICT is running the internal representation of the ICT tangle keeps growing.
(Local snapshots have not been implemented, yet.)
You can avoid this error by restarting ICT on a regular basis.


### Multiple IP addresses

If your ICT node has multiple IP addresses, e.g.
- multiple network interface
- IPv4 and IPv6 dual stack
- multiple stateless IPv6 addresses assigned
the node may use a different IP address for sending transactions than for receiving transactions.

Your neighbours won´t recognize your transactions then, since they seem to be coming from an unknown IP address.
Make sure your outgoing traffic is using the same IP address your neighbours have configured in their `ict.properties` file.

You can check your traffic by running
`sudo tcpdump -vv -n -i any port 14265`
