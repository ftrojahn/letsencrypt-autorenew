# letsencrypt-autorenew
Bash script for auto renew let's encrypt ssl certificates

As you may know all certificates are for 3 months.
So you need to renew them every three monthes. Ouch

Here a way to automate it.

This fork is for hosts with VIRTUALMIN installed (http://www.virtualmin.com).

It checks if "www.domain.tld" exists via dns lookup and request it as alternate dns name, if reachable.

* possible arguments:

  * (domain here) - only special virtualmin domain(s), not all

  * dryrun - just test

  * force (domain here) - renew cert even if not needed, needs domain name

1) Configure config file
nano /PathToLetsencrypt/letsencrypt/cli.ini

2) Edit script to add your domains that you want to renew certificates
nano /PathToLetsencrypt/letsencrypt/cron.sh

3) Don't forget to make it executable
chmod +x /PathToLetsencrypt/letsencrypt/cron.sh

4) Cron exemple: 15 Jan, 15 April, 15 July, 15 Oct 

"* * 15 4,7,10,1 * /PathToLetsencrypt/letsencrypt/cron.sh >> /PathToLetsencrypt/letsencrypt/cron.log"

