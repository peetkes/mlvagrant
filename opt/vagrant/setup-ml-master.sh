#!/bin/bash
echo "running $0 $@"

################################################################
# Use this script to initialize the first (or only) host in
# a MarkLogic Server cluster. Use the options to control admin
# username and password, authentication mode, and the security
# realm. If no hostname is given, localhost is assumed. Only
# minimal error checking is performed, so this script is not
# suitable for production use.
#
# Usage:  this_command [options] hostname
#
################################################################

BOOTSTRAP_HOST="localhost"
USER="admin"
PASS="admin"
AUTH_MODE="anyauth"
VERSION="7.0-5.1"
SEC_REALM="public"
N_RETRY=5
RETRY_INTERVAL=10

#######################################################
# restart_check(hostname, baseline_timestamp, caller_lineno)
#
# Use the timestamp service to detect a server restart, given a
# a baseline timestamp. Use N_RETRY and RETRY_INTERVAL to tune
# the test length. Include authentication in the curl command
# so the function works whether or not security is initialized.
#   $1 :  The hostname to test against
#   $2 :  The baseline timestamp
#   $3 :  Invokers LINENO, for improved error reporting
# Returns 0 if restart is detected, exits with an error if not.
#
function restart_check {
  echo "restart check for $1..."
  LAST_START=`$AUTH_CURL "http://$1:8001/admin/v1/timestamp"`
  for i in `seq 1 ${N_RETRY}`; do
    if [ "$2" == "$LAST_START" ] || [ "$LAST_START" == "" ]; then
      sleep ${RETRY_INTERVAL}
      LAST_START=`$AUTH_CURL "http://$1:8001/admin/v1/timestamp"`
    else 
      return 0
    fi
  done
  echo "ERROR: Line $3: Failed to restart $1"
  exit 1
}


#######################################################
# Parse the command line

OPTIND=1
while getopts ":a:p:r:u:v:" opt; do
  case "$opt" in
    a) AUTH_MODE=$OPTARG ;;
    p) PASS=$OPTARG ;;
    r) SEC_REALM=$OPTARG ;;
    u) USER=$OPTARG ;;
    v) VERSION=$OPTARG ;;
    \?) echo "Unrecognized option: -$OPTARG" >&2; exit 1 ;;
  esac
done
shift $((OPTIND-1))

if [ $# -ge 1 ]; then
  BOOTSTRAP_HOST=$1
  shift
fi

MAIN_VERSION="$(echo $VERSION | head -c 1)"

source /opt/vagrant/ml_${MAIN_VERSION}_license.properties

echo "BOOTSTRAP_HOST is ${BOOTSTRAP_HOST}"
echo "VERSION is ${VERSION}"
echo "USER is ${USER}"
echo "LICENSEE is ${LICENSEE}"

# Suppress progress meter, but still show errors
CURL="curl -s -S"
#for debugging:
#CURL="curl -v"

# Add authentication related options, required once security is initialized
AUTH_CURL="${CURL} --${AUTH_MODE} --user ${USER}:${PASS}"

if [ "$MAIN_VERSION" -eq "5" ] || [ "$MAIN_VERSION" -eq "6" ]; then
	
	echo Uploading license..
	$CURL -i -X POST \
	    --data-urlencode "license-key=$LICENSE" \
	    --data-urlencode "licensee=$LICENSEE" \
	    --data-urlencode "ok=ok" \
	    http://${BOOTSTRAP_HOST}:8001/license-go.xqy
	service MarkLogic restart
	echo "Waiting for server restart.."
	sleep 5

	echo Agreeing license..
	$CURL -i -X GET \
	    http://${BOOTSTRAP_HOST}:8001/agree.xqy > agree.html
	LOCATION=`grep "Location:" agree.html \
		| perl -p -e 's/^.*?Location:\s+([^\r\n\s]+).*/$1/'`
	echo "'$LOCATION'"
	
	$CURL -o "agree.html" -X GET \
	    "http://${BOOTSTRAP_HOST}:8001/${LOCATION}"
	AGREE=`grep "accepted-agreement" agree.html \
		| sed 's%^.*value="\(.*\)".*$%\1%'`
	
	echo "AGREEMENT is $AGREE"
	$CURL -X POST \
	    --data-urlencode "accepted-agreement=$AGREE" \
	    --data-urlencode "ok=ok" \
	    http://${BOOTSTRAP_HOST}:8001/agree-go.xqy
	service MarkLogic restart
	echo "Waiting for server restart.."
	sleep 5
	
	echo Initializing services..
	$CURL -X POST \
	    --data-urlencode "ok=ok" \
	    http://${BOOTSTRAP_HOST}:8001/initialize-go.xqy
	service MarkLogic restart
	echo "Waiting for server restart.."
	sleep 5
	
	echo Initializing security..
	$CURL -X POST \
	    --data-urlencode "user=$USER" \
	    --data-urlencode "password1=$PASS" \
	    --data-urlencode "password2=$PASS" \
	    --data-urlencode "realm=$SEC_REALM" \
	    --data-urlencode "ok=ok" \
	    http://${BOOTSTRAP_HOST}:8001/security-install-go.xqy
	service MarkLogic restart
	echo "Waiting for server restart.."
	sleep 5
	
	rm *.html
else
	
	#######################################################
	# Bring up the first (or only) host in the cluster. The following
	# requests are sent to the target host:
	#   (1) POST /admin/v1/init
	#   (2) POST /admin/v1/instance-admin?admin-user=X&admin-password=Y&realm=Z
	# GET /admin/v1/timestamp is used to confirm restarts.

	# (1) Initialize the server
	echo "Initializing $BOOTSTRAP_HOST and setting license..."
	$CURL -X POST -H "Content-type=application/x-www-form-urlencoded" \
	    --data-urlencode "license-key=$LICENSE" \
	    --data-urlencode "licensee=$LICENSEE" \
	    http://${BOOTSTRAP_HOST}:8001/admin/v1/init
	sleep 10

	# (2) Initialize security and, optionally, licensing. Capture the last
	#     restart timestamp and use it to check for successful restart.
	echo "Initializing security for $BOOTSTRAP_HOST..."
	TIMESTAMP=`$CURL -X POST \
	   -H "Content-type: application/x-www-form-urlencoded" \
	   --data "admin-username=${USER}" --data "admin-password=${PASS}" \
	   --data "realm=${SEC_REALM}" \
	   http://${BOOTSTRAP_HOST}:8001/admin/v1/instance-admin \
	   | grep "last-startup" \
	   | sed 's%^.*<last-startup.*>\(.*\)</last-startup>.*$%\1%'`
	if [ "$TIMESTAMP" == "" ]; then
	  echo "ERROR: Failed to get instance-admin timestamp." >&2
	  exit 1
	fi

	# Test for successful restart
	restart_check $BOOTSTRAP_HOST $TIMESTAMP $LINENO
fi

echo "Removing network suffix from hostname"

$AUTH_CURL -o "hosts.html" -X GET \
    "http://${BOOTSTRAP_HOST}:8001/host-summary.xqy?section=host"
HOST_ID=`grep "statusfirstcell" hosts.html \
	| grep ${BOOTSTRAP_HOST} \
	| sed 's%^.*href="host-admin.xqy?section=host&amp;host=\([^"]*\)".*$%\1%'`
echo "HOST_ID is $HOST_ID"

$AUTH_CURL -X POST \
	--data-urlencode "host=$HOST_ID" \
	--data-urlencode "section=host" \
	--data-urlencode "/ho:hosts/ho:host/ho:host-name=${BOOTSTRAP_HOST}" \
	--data-urlencode "ok=ok" \
	"http://${BOOTSTRAP_HOST}:8001/host-admin-go.xqy"

service MarkLogic restart
echo "Waiting for server restart.."
sleep 5

rm *.html

echo "Initialization complete for $BOOTSTRAP_HOST..."
exit 0