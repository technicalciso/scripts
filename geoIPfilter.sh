#!/bin/bash
# Author: Ely Pinto https://technicalCISO.com
#
# Assumes geoiplookup is available and IP database is up to date
# Assumes fail2ban is setup and working
# Assumes tcp wrappers is setup and working
# Untested with IPv6 but should work
#
# Add to /etc/hosts.allow
# sshd: ALL: spawn (/usr/local/bin/geoIPfilter.sh %a)
#
# TODO: should check $1 for valid IP or hostname (see notes below).
#       should check $allowed to make sure its not empty
#       add a flag for testing that doesn't actually perform the ban.  in the meantime use a short jailtime (e.g. 30 seconds or less) to test
#       more flexible logging options (allowed and banned, just banned, none, etc.)
#
# NOTES (largely unimportant now that the script uses fail2ban, but could be useful if rewriting to use aclexec on debian based systems):
#       when called by tcp wrappers, script exit 0 will allow access, anything else will deny
#       if IP isn't found (e.g. 127.0.0.1 or 10.0.0.1) then script exits 0 to allow
#       usage clause exits 0 to allow access in case of script error/misconfiguration
#       invalid hostnames cause geoiplookup to exit with error code 1

# BINARY LOCATIONS
GEOIPLOOKUP=/bin/geoiplookup
CUT=/bin/cut
EGREP=/bin/egrep
LOGGER=/bin/logger
FAIL2BANCLIENT=/bin/fail2ban-client #do not include the dash in variable name

#the name of the jail you want to use to ban
jail=sshd

# Space-separated country codes to ACCEPT #see https://www.geonames.org/countries/ for iso3166 codes
# MUST be uppercase
allowed="US"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <ip>" 1>&2
  exit 0
fi

country=$($GEOIPLOOKUP $1 | $CUT -d":" -f 2 | $CUT -d"," -f1)
[[ "$country" =~ "IP Address not found" ]] && exit 0 || echo "$allowed" | $EGREP -q $country && exit 0

#if we are here, time to ban!
$LOGGER geoIPfilter.sh: Banned $1 from $country
$FAIL2BANCLIENT set $jail banip $1 > /dev/null
