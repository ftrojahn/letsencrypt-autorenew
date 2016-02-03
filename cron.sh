#!/bin/bash

LETSENCRYPT_DIRECTORY="/root/letsencrypt"
CONFIG_PATH="/root/letsencrypt-autorenew/cli.ini"
VIRTUALMINBIN="/usr/sbin/virtualmin"

if [ "$1" = "dryrun" ] ; then
 DRYRUN=true
 shift
else
 DRYRUN=false
fi

if [ "$1" = "force" ] ; then
 FORCE=true
 shift
 if [ -z $@ ] ; then
   echo Force - only for single domains ...
   exit 1
 fi
else
 FORCE=false
fi

if [ -n $@ ] ; then
	VIRTUALHOSTS=$@
fi

ISINSTALLED=`which bc`
if [ -z "$ISINSTALLED" ] ; then
 	echo PLEASE DO: apt-get install bc
	exit 1
fi
ISINSTALLED=`which host`
if [ -z "$ISINSTALLED" ] ; then
 	echo PLEASE DO: apt-get install bind9-host
	exit 1
fi

if [ ! -f "$VIRTUALMINBIN" ] ; then
 	echo "PLEASE NOTE: this script is for virtualmin hosts only!"
	exit 1
fi



echo "Start ..."
################
# Script Start #
################"
# We display date
date

cd $LETSENCRYPT_DIRECTORY

#array domains
declare -A DOMAINS
declare -A CERTS
declare -A KEYS

#you can add more elements
#DOMAINS["xx.domain.tld"]="/your-special-document-root-path/public/"
#CERTS["xx.domain.tld"]="/etc/letsencrypt/live/xx.domain.tld/fullchain.pem"
#KEYS["xx.domain.tld"]="/etc/letsencrypt/live/xx.domain.tld/privkey.pem"

############ no more variable settings after this line ##################

if [ -z $VIRTUALHOSTS ] ; then

	VIRTUALHOSTS=`$VIRTUALMINBIN list-domains --enabled --with-feature ssl --name-only`
fi

LETSENCRYPTDOMAINS=`ls -1 /etc/letsencrypt/live/ | tr "\n" " "`
for i in $VIRTUALHOSTS ; do
	# so, we get all other domains with older certificates, too
	VHOSTHOME=`$VIRTUALMINBIN list-domains --enabled --with-feature ssl --domain $i --home-only`
	DOMAINS["$i"]="$VHOSTHOME/public_html/"
	VHOSTCERT_FILE=`$VIRTUALMINBIN list-domains --enabled --with-feature ssl --simple-multiline --domain $i 2>/dev/null | grep "  SSL cert file:" | cut -d":" -f2`
	if [ -z $VHOSTCERT_FILE ] ; then
	   for j in $LETSENCRYPTDOMAINS ; do
		if [ "$i" = "$j" ] ; then
		   # echo DEBUG: letsencrypt-domain found: $i
		   VHOSTCERT_FILE=/etc/letsencrypt/live/$i/fullchain.pem 
		fi
	  done
        fi

	VHOSTKEY_FILE=`$VIRTUALMINBIN list-domains --enabled --with-feature ssl --simple-multiline --domain $i 2>/dev/null | grep "  SSL key file:" | cut -d":" -f2`
	if [ -z $VHOSTKEY_FILE ] ; then
	   for j in $LETSENCRYPTDOMAINS ; do
		if [ "$i" = "$j" ] ; then
		   # echo DEBUG: letsencrypt-domain found: $i
		   VHOSTKEY_FILE=/etc/letsencrypt/live/$i/privkey.pem 
		fi
	  done
        fi
	# trim white spaces
	shopt -s extglob
	VHOSTCERT_FILE="${VHOSTCERT_FILE##*( )}"
	VHOSTCERT_FILE="${VHOSTCERT_FILE%%*( )}"
	VHOSTKEY_FILE="${VHOSTKEY_FILE##*( )}"
	VHOSTKEY_FILE="${VHOSTKEY_FILE%%*( )}"

	shopt -u extglob
	CERTS["$i"]="$VHOSTCERT_FILE"
	KEYS["$i"]="$VHOSTKEY_FILE"
done

echo

for i in "${!DOMAINS[@]}"
do
	#domain name
	domain=$i
	#domain path
	path=${DOMAINS[$domain]};
	exp_limit=30;

	echo -e "\n\n############################################"
	echo -e "\nDomain $domain : $path "

CERT_FILE=${CERTS[$domain]};
KEY_FILE=${KEYS[$domain]};

	if [ ! -f $CERT_FILE ] ; then
		echo "Zertifikat $domain Datei existiert nicht: $CERT_FILE."
		continue
        fi

	echo "Checking expiration date for $domain..."
	exp=$(date -d "`openssl x509 -in $CERT_FILE -text -noout|grep "Not After"|cut -c 25-`" +%s)
	datenow=$(date -d "now" +%s)
	days_exp=$(echo \( $exp - $datenow \) / 86400 |bc)
	dnsnames=$( openssl x509 -in $CERT_FILE -text -noout|grep "DNS:")

		if [ "$FORCE" = "true" ] ; then
			echo "Certificate $domain renew is forced ($days_exp days left)."
			echo "Trying to create new cert using Letsencrypt ..."
			days_exp=1;
		fi 
		if [ "$days_exp" -gt "1800" ] ; then
			echo "Certificate $domain is self-signed ($days_exp days left)."
			echo "Trying to create new cert using Letsencrypt ..."
			days_exp=1;
		fi 
  if [ "$days_exp" -gt "90" ] ; then
	echo "Zertifikat $domain ist nicht von Let's Encrypt ($days_exp days left)."
 	continue
  fi 

    WWWARG=" "
    echo -e "Checking www.${domain} ..."   
    host www.${domain}
    if [ $? -eq 0 ] ; then
		echo " ... exists OK"
		WWWARG="-d www.${domain}"
    fi

  if [ "$days_exp" -gt "$exp_limit" ] ; then
	echo "The certificate for $domain is up to date, no need for renewal ($days_exp days left)."
	echo "Domains: $dnsnames "
  else
	if [ "$DRYRUN" = "true" ] ; then
		#display command
	        echo "letsencrypt-auto --config ${CONFIG_PATH} -d ${domain} ${WWWARG} --webroot-path ${path} certonly"
		echo "Cert file: $CERT_FILE"
			 diff -q /etc/letsencrypt/live/$domain/fullchain.pem $CERT_FILE 
		# copy files if needed
		if [ -n "$CERT_FILE" ] && [ -f "$CERT_FILE" ] &&
			 [ -L "/etc/letsencrypt/live/$domain/fullchain.pem" ] && [ "$CERT_FILE" != "/etc/letsencrypt/live/$domain/fullchain.pem" ] ; then
			 echo cp -L /etc/letsencrypt/live/$domain/fullchain.pem $CERT_FILE 
		fi
		echo "Key file: $KEY_FILE"
			 diff -q /etc/letsencrypt/live/$domain/privkey.pem $KEY_FILE 
		if [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ] &&
			 [ -L "/etc/letsencrypt/live/$domain/privkey.pem" ] && [ "$KEY_FILE" != "/etc/letsencrypt/live/$domain/privkey.pem" ] ; then
			 echo cp -L /etc/letsencrypt/live/$domain/privkey.pem $KEY_FILE 
		fi
	else
		#run command
	        result=$(./letsencrypt-auto  --config ${CONFIG_PATH} -d ${domain} ${WWWARG} --webroot-path ${path} certonly )
		echo "${result}"

		# copy files if needed
		if [ -n "$CERT_FILE" ] && [ -f "$CERT_FILE" ] &&
			 [ -L "/etc/letsencrypt/live/$domain/fullchain.pem" ] && [ "$CERT_FILE" != "/etc/letsencrypt/live/$domain/fullchain.pem" ] ; then
			 cp -L /etc/letsencrypt/live/$domain/fullchain.pem $CERT_FILE 
		fi
		if [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ] &&
			 [ -L "/etc/letsencrypt/live/$domain/privkey.pem" ] && [ "$KEY_FILE" != "/etc/letsencrypt/live/$domain/privkey.pem" ] ; then
			 cp -L /etc/letsencrypt/live/$domain/privkey.pem $KEY_FILE 
		fi
	fi

  fi
done

if [ "$DRYRUN" = "false" ] ; then
	echo "Reload Apache"
	/etc/init.d/apache2 reload
fi

# We display date
echo "End of script"
date
