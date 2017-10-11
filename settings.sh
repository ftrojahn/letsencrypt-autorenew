
LETSENCRYPT_cmd="/usr/local/bin/dehydrated -c -4 "
LETSENCRYPT_options=" "
LETSENCRYPT_path="/var/lib/dehydrated/certs"
VIRTUALMINBIN="/usr/sbin/virtualmin"

POSTFIXDOMAIN="domain.tld"
POSTFIXCERTFILE="/etc/postfix/domain-fullchain.pem"
POSTFIXKEYFILE="/etc/postfix/domain-privkey.pem"

DOVECOTDOMAIN="domain.tld"
DOVECOTCERTFILE="/etc/postfix/domain-fullchain.pem"
DOVECOTKEYFILE="/etc/postfix/domain-privkey.pem"


DOMAINSLOCAL["git.domain.tld"]="/opt/gitlab/embedded/service/gitlab-rails/public/"
CERTSLOCAL["git.domain.tld"]=/etc/letsencrypt/live/domain.tld/fullchain.pem 
KEYSLOCAL["git.domain.tld"]=/etc/letsencrypt/live/domain.tld/privkey.pem 



