#!/bin/bash

MYPATH="`dirname \"$0\"`"
declare -A DOMAINSLOCAL
declare -A DOMAINROOTSLOCAL
declare -A CERTSLOCAL
declare -A KEYSLOCAL

echo "Pfad: $PATH"

source $MYPATH/settings.sh

DORELOAD=false
DODOVECOTRELOAD=false
DOPOSTFIXRELOAD=false

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
ISINSTALLED=`which certtool`
if [ -z "$ISINSTALLED" ] ; then
 	echo PLEASE DO: apt-get install gnutls-bin
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
declare -A ALTNAMES
declare -A CERTS
declare -A KEYS

#you can add more elements
#DOMAINSLOCAL["xx.domain.tld"]="xx.domain.tld"
#DOMAINROOTSLOCAL["xx.domain.tld"]="/your-special-document-root-path/public/"
#CERTSLOCAL["xx.domain.tld"]="$LETSENCRYPT_path/xx.domain.tld/fullchain.pem"
#KEYSLOCAL["xx.domain.tld"]="$LETSENCRYPT_path/xx.domain.tld/privkey.pem"

for i in "${!DOMAINSLOCAL[@]}"
do
  if [ -z "$VIRTUALHOSTS" ] || [ "$VIRTUALHOSTS" = "$i" ] ; then
      DOMAINS[$i]=${DOMAINSLOCAL[$i]}
      CERTS[$i]=${CERTSLOCAL[$i]}
      KEYS[$i]=${KEYSLOCAL[$i]}
  fi
done

if [ -z $VIRTUALHOSTS ] ; then

############ no more variable settings after this line ##################

	VIRTUALHOSTS=`$VIRTUALMINBIN list-domains --enabled --with-feature ssl --name-only`
fi

LETSENCRYPTDOMAINS=`ls -1 $LETSENCRYPT_path/ | tr "\n" " "`
for i in $VIRTUALHOSTS ; do
        # already set - perhaps from LOCAL
        test1=${DOMAINS[$i]} 
        test2=${CERTS[$i]}
        test3=${KEYS[$i]}
        if [ -n "$test1" ] && [ -n "$test2" ] && [ -n "$test3" ] ; then
          echo got local settings for $i
          continue
        fi
        unset test1
        unset test2
        unset test3
	# so, we get all other domains with older certificates, too
	VHOSTHOME=`$VIRTUALMINBIN list-domains --enabled --with-feature ssl --domain $i --home-only`
	DOMAINS["$i"]="$VHOSTHOME/public_html/"
	VHOSTCERT_FILE=`$VIRTUALMINBIN list-domains --enabled --with-feature ssl --simple-multiline --domain $i 2>/dev/null | grep "  SSL cert file:" | cut -d":" -f2`
	if [ -z $VHOSTCERT_FILE ] ; then
             echo "SSL not enabled in Virtualmin"
	   for j in $LETSENCRYPTDOMAINS ; do
		if [ "$i" = "$j" ] ; then
		   # echo DEBUG: letsencrypt-domain found: $i
		   VHOSTCERT_FILE=$LETSENCRYPT_path/$i/fullchain.pem 
		fi
	  done
        fi

	VHOSTKEY_FILE=`$VIRTUALMINBIN list-domains --enabled --with-feature ssl --simple-multiline --domain $i 2>/dev/null | grep "  SSL key file:" | cut -d":" -f2`
	if [ -z $VHOSTKEY_FILE ] ; then
	   for j in $LETSENCRYPTDOMAINS ; do
		if [ "$i" = "$j" ] ; then
		   # echo DEBUG: letsencrypt-domain found: $i
		   VHOSTKEY_FILE=$LETSENCRYPT_path/$i/privkey.pem 
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

	VHOSTDOMAINS=`$VIRTUALMINBIN list-domains --enabled --with-feature ssl --simple-multiline --domain $i 2>/dev/null | grep "  Lets Encrypt domain:" | cut -d":" -f2`
        if [ -f "$VHOSTCERT_FILE" ] ; then 
          MAIN=`certtool  --certificate-info --infile $VHOSTCERT_FILE | grep " CN=" | cut -d"=" -f2 | sed -e 's@ @@g'`
          CERTTOOL=`certtool  --certificate-info --infile $VHOSTCERT_FILE | grep DNSname: | cut -d":" -f2 | sed -e 's@ @@g'`
 
          VHOSTALTNAMES="$MAIN"
          for j in $CERTTOOL ; do
           if [ "$j" != "$MAIN" ] ; then
             VHOSTALTNAMES="$DOMAINS $j"
           fi
          done
          if [ -n "$VHOSTALTNAMES" ] ; then
            echo "found in cert: $VHOSTALTNAMES"
          fi
        fi 
	if [ -z "$VHOSTDOMAINS" ] ; then
          ALTNAMES["$i"]="$VHOSTALTNAMES"
        else
          ALTNAMES["$i"]="$VHOSTDOMAINS"
        fi
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
		echo "Certificate file for $domain does not exist: $CERT_FILE."
		continue
        fi
	if [ ! -f $KEY_FILE ] ; then
		echo "Key file for $domain does not exist: $KEY_FILE."
		continue
        fi

	echo "Checking expiration date for $domain..."
	exp=$(date -d "`openssl x509 -in $CERT_FILE -text -noout|grep "Not After"|cut -c 25-`" +%s)
	datenow=$(date -d "now" +%s)
	days_exp=$(echo \( $exp - $datenow \) / 86400 |bc)
	dnsnames=$( openssl x509 -in $CERT_FILE -text -noout|grep "DNS:")

		if [ "$FORCE" = "true" ] ; then
			echo "Certificate $domain renew is forced: *left $days_exp days*"
			echo "Trying to create new cert using Letsencrypt ..."
			days_exp=1;
		fi 
		if [ "$days_exp" -gt "1800" ] ; then
			echo "Certificate $domain is self-signed: *left $days_exp days*"
			echo "Trying to create new cert using Letsencrypt ..."
			days_exp=1;
		fi 
  if [ "$days_exp" -gt "90" ] ; then
	echo "Certificate for $domain is not from Let's Encrypt: *left $days_exp days*"
 	continue
  fi 

    WWWARG=""
    MYDOMAINS=${ALTNAMES[$domain]}
    if [ -z "$MYDOMAINS" ] ; then
      for k in ${domain} www.${domain} ; do
        echo -n "Checking ${k} ..."   
        host ${k} >/dev/null 2>&1
        if [ $? -eq 0 ] ; then
            	echo -n " OK "
            	WWWARG="$WWWARG -d ${k}"
        fi
      done
    else
      for k in $MYDOMAINS ; do
        echo -n "Checking ${k} ..."   
        host ${k} >/dev/null 2>&1
        if [ $? -eq 0 ] ; then
            	echo -n " OK "
            	WWWARG="$WWWARG -d ${k}"
        fi
      done
    fi
    echo done.

  if [ "$days_exp" -gt "$exp_limit" ] ; then
	echo "The certificate for $domain is *up to date*, no need for renewal: *left $days_exp days*"
	echo "Domains: $dnsnames "
  else
	if [ "$DRYRUN" = "true" ] ; then
		#display command
	        echo "${LETSENCRYPT_cmd} ${WWWARG} ${LETSENCRYPT_options}"
		echo "Cert file: $CERT_FILE"
			 diff -q $LETSENCRYPT_path/$domain/fullchain.pem $CERT_FILE 
		# copy files if needed
		if [ -n "$CERT_FILE" ] && [ -f "$CERT_FILE" ] &&
			 [ -L "$LETSENCRYPT_path/$domain/fullchain.pem" ] && [ "$CERT_FILE" != "$LETSENCRYPT_path/$domain/fullchain.pem" ] ; then
			 echo cp -L $LETSENCRYPT_path/$domain/fullchain.pem $CERT_FILE 
		fi
		echo "Key file: $KEY_FILE"
			 diff -q $LETSENCRYPT_path/$domain/privkey.pem $KEY_FILE 
		if [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ] &&
			 [ -L "$LETSENCRYPT_path/$domain/privkey.pem" ] && [ "$KEY_FILE" != "$LETSENCRYPT_path/$domain/privkey.pem" ] ; then
			 echo cp -L $LETSENCRYPT_path/$domain/privkey.pem $KEY_FILE 
		fi
	else
		#run command
	        result=$(${LETSENCRYPT_cmd} ${WWWARG} ${LETSENCRYPT_options} )
		echo "${result}"
	fi
  fi

  exp2=0
 if [ -e $LETSENCRYPT_path/$domain/fullchain.pem ] ; then
    exp2=$(date -d "`openssl x509 -in $LETSENCRYPT_path/$domain/fullchain.pem -text -noout|grep "Not After"|cut -c 25-`" +%s)
  datenow2=$(date -d "now" +%s)
  days_exp2=$(echo \( $exp2 - $datenow2 \) / 86400 |bc)
  dnsnames2=$( openssl x509 -in $LETSENCRYPT_path/$domain/fullchain.pem -text -noout|grep "DNS:")
  
  # copy files if needed
  if [ $days_exp2 -ge $days_exp ] \
    && [ -n "$CERT_FILE" ] && [ -f "$CERT_FILE" ] && [ -L "$LETSENCRYPT_path/$domain/fullchain.pem" ] \
    && [ -n "$KEY_FILE" ] && [ -f "$KEY_FILE" ] && [ -L "$LETSENCRYPT_path/$domain/privkey.pem" ] ; then
  	cp -L $LETSENCRYPT_path/$domain/fullchain.pem $CERT_FILE 
  	cp -L $LETSENCRYPT_path/$domain/privkey.pem $KEY_FILE 
  	DORELOAD=true
        if [ -n "$POSTFIXDOMAIN" ] && [ "$POSTFIXDOMAIN" == "${domain}" ] ; then
           [ "$CERT_FILE" != "$POSTFIXCERTFILE" ] && cp -L $LETSENCRYPT_path/$domain/fullchain.pem $POSTFIXCERTFILE && DOPOSTFIXRELOAD=true
           [ "$KEY_FILE" != "$POSTFIXKEYFILE" ]   && cp -L $LETSENCRYPT_path/$domain/privkey.pem $POSTFIXKEYFILE && DOPOSTFIXRELOAD=true
        fi
        if [ -n "$DOVECOTDOMAIN" ] && [ "$DOVECOTDOMAIN" == "${domain}" ] ; then
           [ "$CERT_FILE" != "$DOVECOTCERTFILE" ] && cp -L $LETSENCRYPT_path/$domain/fullchain.pem $DOVECOTCERTFILE && DODOVECOTRELOAD=true
           [ "$KEY_FILE" != "$DOVECOTKEYFILE" ]   && cp -L $LETSENCRYPT_path/$domain/privkey.pem $DOVECOTKEYFILE && DODOVECOTRELOAD=true
        fi
  fi
 else
  echo "... no cert in $LETSENCRYPT_path/$domain/ "
 fi
done

if [ "$DORELOAD" = "true" ] ; then
	echo "Reload Apache"
	/usr/sbin/apache2ctl -t && /usr/sbin/apache2ctl graceful
fi
if [ "$DOPOSTFIXRELOAD" = "true" ] ; then
	echo "Reload Postfix"
	/usr/sbin/service postfix reload
fi
if [ "$DODOVECOTRELOAD" = "true" ] ; then
	echo "Reload Dovecot"
	/usr/sbin/service dovecot reload
fi

# We display date
echo "End of script"
date
