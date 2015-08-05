#!/bin/bash
echo "running $0 $@"

################################################################
# Use this script to couple a master and replica cluster
# Both (bootstrap) hosts for the
# clusters should already be fully initialized.
#
# Use the options to control admin username and password, 
# authentication mode, and the security realm. Two hostnames
# must be given: The bootstrap host for the master cluster, and the bootstrap host
# for the Replica cluster. Only minimal error checking is performed, 
# so this script is not suitable for production use.
#
# Usage:  this_command [options] bootstrap-master-host bootstrap-replica-host
#
################################################################
USER="admin"
PASS="admin"
AUTH_MODE="anyauth"
VERSION="7.0-5.1"
N_RETRY=5
RETRY_INTERVAL=10
SKIP=0

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
  LAST_START=`$AUTH_CURL "http://$1:8001/admin/v1/timestamp"`
  for i in `seq 1 ${N_RETRY}`; do
    echo "restart check for $1..."
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
while getopts ":a:p:u:v:m:r:" opt; do
  case "$opt" in
    a) AUTH_MODE=$OPTARG ;;
    p) PASS=$OPTARG ;;
    u) USER=$OPTARG ;;
    m) BOOTSTRAP_MASTER_HOST=$OPTARG ;;
    r) BOOTSTRAP_REPLICA_HOST=$OPTARG ;;
    v) VERSION=$OPTARG ;;
    \?) echo "Unrecognized option: -$OPTARG" >&2; exit 1 ;;
  esac
done
shift $((OPTIND-1))

MAIN_VERSION="$(echo $VERSION | head -c 1)"

echo "BOOTSTRAP_MASTER_HOST is ${BOOTSTRAP_MASTER_HOST}"
echo "BOOTSTRAP_REPLICA_HOST is ${BOOTSTRAP_REPLICA_HOST}"
echo "VERSION is ${VERSION}"

# Suppress progress meter, but still show errors
CURL="curl -s -S"
#for debugging:
#CURL="curl -v"

# Add authentication related options, required once security is initialized
AUTH_CURL="${CURL} --${AUTH_MODE} --user ${USER}:${PASS}"

if [ "$MAIN_VERSION" -eq "5" ] || [ "$MAIN_VERSION" -eq "6" ] || [ "$MAIN_VERSION" -eq "7" ]; then

if ! rpm -qa | grep recode; then
	yum -y install recode
fi

	$AUTH_CURL -o step1.html -X GET  http://${BOOTSTRAP_MASTER_HOST}:8001/dbrep-couple-foreign-cluster.xqy?
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	
	FOREIGN_PORT=`grep "foreign-port" step1.html \
		| sed 's%^.*value="\([^"]*\)".*$%\1%'`
	SELECT=`sed -e '/<select name="foreign-protocol">/,/<\/select>/!d' step1.html`
	echo "$SELECT" > select.html
	FOREIGN_PROTOCOL=`grep '<option value=".*" selected="true">.*</option>' select.html | sed 's%^.*value="\([^"]*\)" selected="true".*$%\1%'`		
#	echo "foreign-host = $BOOTSTRAP_REPLICA_HOST"
#	echo "foreign-port = $FOREIGN_PORT"
#	echo "foreign-protocol = $FOREIGN_PROTOCOL"
	$AUTH_CURL -i -o step2.html -X POST \
		--data-urlencode "foreign-host-name=$BOOTSTRAP_REPLICA_HOST" \
	    --data-urlencode "foreign-port=$FOREIGN_PORT" \
	    --data-urlencode "foreign-protocol=$FOREIGN_PROTOCOL" \
	    http://${BOOTSTRAP_MASTER_HOST}:8001/dbrep-couple-foreign-cluster-confirm-ssl.xqy
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
#	cat step2.html
#	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

	XDQP_SSL_ENABLED=`grep "xdqp-ssl-enable" step2.html| sed 's%^.*value="\([^"]*\)" checked="true".*$%\1%'`    
	XDQP_SSL_ALLOW_SSLV3=`grep "xdqp-ssl-allow-sslv3" step2.html| sed 's%^.*value="\([^"]*\)" checked="true".*$%\1%'`    
	XDQP_SSL_ALLOW_TLS=`grep "xdqp-ssl-allow-tls" step2.html| sed 's%^.*value="\([^"]*\)" checked="true".*$%\1%'`    
	XDQP_SSL_CIPHERS=`grep 'name="xdqp-ssl-ciphers"' step2.html| sed 's%^.*value="\([^"]*\)".*$%\1%'`    
	XDQP_TIMEOUT=`grep 'name="xdqp-timeout"' step2.html| sed 's%^.*value="\([^"]*\)".*$%\1%'`    
	HOST_TIMEOUT=`grep 'name="host-timeout"' step2.html| sed 's%^.*value="\([^"]*\)".*$%\1%'`
#	echo "XDQP_SSL_ENABLED = $XDQP_SSL_ENABLED"
#	echo "XDQP_SSL_ALLOW_SSLV3 = $XDQP_SSL_ALLOW_SSLV3"
#	echo "XDQP_SSL_ALLOW_TLS = $XDQP_SSL_ALLOW_TLS"
#	echo "XDQP_SSL_CIPHERS = $XDQP_SSL_CIPHERS"
#	echo "XDQP_TIMEOUT = $XDQP_TIMEOUT"
#	echo "HOST_TIMEOUT = $HOST_TIMEOUT"
	$AUTH_CURL -i -o step3.html -X POST \
		--data-urlencode "foreign-host-name=$BOOTSTRAP_REPLICA_HOST" \
	    --data-urlencode "foreign-port=$FOREIGN_PORT" \
	    --data-urlencode "foreign-protocol=$FOREIGN_PROTOCOL" \
	    --data-urlencode "xdqp-ssl-enabled=$XDQP_SSL_ENABLED" \
	    --data-urlencode "xdqp-ssl-allow-sslv3=$XDQP_SSL_ALLOW_SSLV3" \
	    --data-urlencode "xdqp-ssl-allow-tls=$XDQP_SSL_ALLOW_TLS" \
	    --data-urlencode "xdqp-ssl-ciphers=$XDQP_SSL_CIPHERS" \
	    --data-urlencode "xdqp-timeout=$XDQP_TIMEOUT" \
	    --data-urlencode "host-timeout=$HOST_TIMEOUT" \
	    http://${BOOTSTRAP_MASTER_HOST}:8001/dbrep-couple-foreign-cluster-confirm-go.xqy
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
#	LOCATION=`grep "Location:" step3.html \
#		| sed 's%^.*Location: \(.*\)$%\1%'`
#	echo "$LOCATION"
#	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	
	LOCAL_HOST_WITH_PORT=`grep "Location:" step3.html | sed 's%^.*local-host-with-port=\([^&]*\)&.*$%\1%'`
	LOCAL_PROTOCOL=`grep "Location:" step3.html | sed 's%^.*local-protocol=\([^&]*\)&.*$%\1%'`
	LOCAL_CLUSTER_ID=`grep "Location:" step3.html | sed 's%^.*local-cluster-id=\([^&]*\)&.*$%\1%'`
	LOCAL_CLUSTER_NAME=`grep "Location:" step3.html | sed 's%^.*local-cluster-name=\([^&]*\)&.*$%\1%'`
	LOCAL_VERSION=`grep "Location:" step3.html | sed 's%^.*local-version=\([^&]*\)&.*$%\1%'`
	LOCAL_PLATFORM=`grep "Location:" step3.html | sed 's%^.*local-platform=\([^&]*\)&.*$%\1%'`
	LOCAL_ARCHITECTURE=`grep "Location:" step3.html | sed 's%^.*local-architecture=\([^&]*\)&.*$%\1%'`
	BOOTSTRAP_HOST_NAME_1=`grep "Location:" step3.html | sed 's%^.*bootstrap-host-name-1=\([^&]*\)&.*$%\1%'`
	BOOTSTRAP_HOST_ID_1=`grep "Location:" step3.html | sed 's%^.*bootstrap-host-id-1=\([^&]*\)&.*$%\1%'`
	BOOTSTRAP_PORT_1=`grep "Location:" step3.html | sed 's%^.*bootstrap-port-1=\([^&]*\)&.*$%\1%'`
	XDQP_SSL_ENABLE=`grep "Location:" step3.html | sed 's%^.*xdqp-ssl-enabled=\([^&]*\)&.*$%\1%'`
	XDQP_SSL_ALLOW_SSLV3=`grep "Location:" step3.html | sed 's%^.*xdqp-ssl-allow-sslv3=\([^&]*\)&.*$%\1%'`
	XDQP_SSL_ALLOW_TLS=`grep "Location:" step3.html | sed 's%^.*xdqp-ssl-allow-tls=\([^&]*\)&.*$%\1%'`
	XDQP_SSL_CIPHERS=`grep "Location:" step3.html | sed 's%^.*xdqp-ssl-ciphers=\([^&]*\)&.*$%\1%'`
	XDQP_TIMEOUT=`grep "Location:" step3.html | sed 's%^.*xdqp-timeout=\([^&]*\)&.*$%\1%'`
	HOST_TIMEOUT=`grep "Location:" step3.html | sed 's%^.*host-timeout=\([^&]*\)&.*$%\1%'`
	SSL_CERTIFICATE=`grep "Location:" step3.html | sed 's%^.*ssl-certificate=\([^&]*\)$%\1%'`
#	echo "LOCAL_HOST_WITH_PORT = $LOCAL_HOST_WITH_PORT"
#	echo "LOCAL_PROTOCOL = $LOCAL_PROTOCOL"
#	echo "LOCAL_CLUSTER_ID = $LOCAL_CLUSTER_ID"
#	echo "LOCAL_CLUSTER_NAME = $LOCAL_CLUSTER_NAME"
#	echo "LOCAL_VERSION = $LOCAL_VERSION"
#	echo "LOCAL_PLATFORM = $LOCAL_PLATFORM"
#	echo "LOCAL_ARCHITECTURE = $LOCAL_ARCHITECTURE"
#	echo "BOOTSTRAP_HOSTNAME_1 = $BOOTSTRAP_HOST_NAME_1"
#	echo "BOOTSTRAP_HOST_ID_1 = $BOOTSTRAP_HOST_ID_1"
#	echo "BOOTSTRAP_HOST_PORT_1 = $BOOTSTRAP_PORT_1"
#	echo "XDQP_SSL_ENABLE = $XDQP_SSL_ENABLE"
#	echo "XDQP_SSL_ALLOW_SSLV3 = $XDQP_SSL_ALLOW_SSLV3"
#	echo "XDQP_SSL_ALLOW_TLS = $XDQP_SSL_ALLOW_TLS"
#	echo "XDQP_SSL_CIPHERS = $XDQP_SSL_CIPHERS"
#	echo "XDQP_TIMEOUT = $XDQP_TIMEOUT"
#	echo "HOST_TIMEOUT = $HOST_TIMEOUT"
#	echo "SSL_CERTIFICATE = $SSL_CERTIFICATE"
	$AUTH_CURL -i -o step4.html -X POST \
		--data-urlencode "local-host-with-port=$LOCAL_HOST_WITH_PORT" \
	    --data-urlencode "local-protocol=$LOCAL_PROTOCOL" \
	    --data-urlencode "local-cluster-id=$LOCAL_CLUSTER_ID" \
	    --data-urlencode "local-cluster-name=$LOCAL_CLUSTER_NAME" \
	    --data-urlencode "local-version=$LOCAL_VERSION" \
	    --data-urlencode "local-platform=$LOCAL_PLATFORM" \
	    --data-urlencode "local-architecture=$LOCAL_ARCHITECTURE" \
	    --data-urlencode "bootstrap-host-name-1=$BOOTSTRAP_HOST_NAME_1" \
	    --data-urlencode "bootstrap-host-id-1=$BOOTSTRAP_HOST_ID_1" \
	    --data-urlencode "bootstrap-port-1=$BOOTSTRAP_PORT_1" \
	    --data-urlencode "xdqp-ssl-enabled=$XDQP_SSL_ENABLED" \
	    --data-urlencode "xdqp-ssl-allow-sslv3=$XDQP_SSL_ALLOW_SSLV3" \
	    --data-urlencode "xdqp-ssl-allow-tls=$XDQP_SSL_ALLOW_TLS" \
	    --data-urlencode "xdqp-ssl-ciphers=$XDQP_SSL_CIPHERS" \
	    --data-urlencode "xdqp-timeout=$XDQP_TIMEOUT" \
	    --data-urlencode "host-timeout=$HOST_TIMEOUT" \
	    --data-urlencode "ssl-certificate=$SSL_CERTIFICATE" \
	    http://${BOOTSTRAP_REPLICA_HOST}:8001/dbrep-couple-foreign-cluster-write-on-foreign-cluster-go.xqy
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
#	LOCATION=`grep "Location:" step4.html \
#		| sed 's%^.*Location: \(.*\)$%\1%'`
#	echo "$LOCATION"
#	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

	FOREIGN_CLUSTER_ID=`grep "Location:" step4.html | sed 's%^.*foreign-cluster-id=\([^&]*\)&.*$%\1%'`
	FOREIGN_CLUSTER_NAME=`grep "Location:" step4.html | sed 's%^.*foreign-cluster-name=\([^&]*\)&.*$%\1%'`
	BOOTSTRAP_HOST_NAME_1=`grep "Location:" step4.html | sed 's%^.*bootstrap-host-name-1=\([^&]*\)&.*$%\1%'`
	BOOTSTRAP_HOST_ID_1=`grep "Location:" step4.html | sed 's%^.*bootstrap-host-id-1=\([^&]*\)&.*$%\1%'`
	BOOTSTRAP_PORT_1=`grep "Location:" step4.html | sed 's%^.*bootstrap-port-1=\([^&]*\)&.*$%\1%'`
	XDQP_SSL_ENABLE=`grep "Location:" step4.html | sed 's%^.*xdqp-ssl-enabled=\([^&]*\)&.*$%\1%'`
	XDQP_SSL_ALLOW_SSLV3=`grep "Location:" step4.html | sed 's%^.*xdqp-ssl-allow-sslv3=\([^&]*\)&.*$%\1%'`
	XDQP_SSL_ALLOW_TLS=`grep "Location:" step4.html | sed 's%^.*xdqp-ssl-allow-tls=\([^&]*\)&.*$%\1%'`
	XDQP_SSL_CIPHERS=`grep "Location:" step4.html | sed 's%^.*xdqp-ssl-ciphers=\([^&]*\)&.*$%\1%'`
	XDQP_TIMEOUT=`grep "Location:" step4.html | sed 's%^.*xdqp-timeout=\([^&]*\)&.*$%\1%'`
	HOST_TIMEOUT=`grep "Location:" step4.html | sed 's%^.*host-timeout=\([^&]*\)&.*$%\1%'`
	FOREIGN_SSL_CERTIFICATE=`grep "Location:" step4.html | sed 's%^.*foreign-ssl-certificate=\([^&]*\)$%\1%'`
#	echo "FOREIGN_CLUSTER_ID = $FOREIGN_CLUSTER_ID"
#	echo "FOREIGN_CLUSTER_NAME = $FOREIGN_CLUSTER_NAME"
#	echo "BOOTSTRAP_HOSTNAME_1 = $BOOTSTRAP_HOST_NAME_1"
#	echo "BOOTSTRAP_HOST_ID_1 = $BOOTSTRAP_HOST_ID_1"
#	echo "BOOTSTRAP_HOST_PORT_1 = $BOOTSTRAP_PORT_1"
#	echo "XDQP_SSL_ENABLE = $XDQP_SSL_ENABLE"
#	echo "XDQP_SSL_ALLOW_SSLV3 = $XDQP_SSL_ALLOW_SSLV3"
#	echo "XDQP_SSL_ALLOW_TLS = $XDQP_SSL_ALLOW_TLS"
#	echo "XDQP_SSL_CIPHERS = $XDQP_SSL_CIPHERS"
#	echo "XDQP_TIMEOUT = $XDQP_TIMEOUT"
#	echo "HOST_TIMEOUT = $HOST_TIMEOUT"
#	echo "FOREIGN_SSL_CERTIFICATE = $FOREIGN_SSL_CERTIFICATE"
	$AUTH_CURL -i -o step5.html -X POST \
	    --data-urlencode "foreign-cluster-id=$FOREIGN_CLUSTER_ID" \
	    --data-urlencode "foreign-cluster-name=$FOREIGN_CLUSTER_NAME" \
	    --data-urlencode "bootstrap-host-name-1=$BOOTSTRAP_HOST_NAME_1" \
	    --data-urlencode "bootstrap-host-id-1=$BOOTSTRAP_HOST_ID_1" \
	    --data-urlencode "bootstrap-port-1=$BOOTSTRAP_PORT_1" \
	    --data-urlencode "xdqp-ssl-enabled=$XDQP_SSL_ENABLED" \
	    --data-urlencode "xdqp-ssl-allow-sslv3=$XDQP_SSL_ALLOW_SSLV3" \
	    --data-urlencode "xdqp-ssl-allow-tls=$XDQP_SSL_ALLOW_TLS" \
	    --data-urlencode "xdqp-ssl-ciphers=$XDQP_SSL_CIPHERS" \
	    --data-urlencode "xdqp-timeout=$XDQP_TIMEOUT" \
	    --data-urlencode "host-timeout=$HOST_TIMEOUT" \
	    --data-urlencode "foreign-ssl-certificate=$FOREIGN_SSL_CERTIFICATE" \
	    http://${BOOTSTRAP_MASTER_HOST}:8001/dbrep-couple-local-cluster-write-go.xqy
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

# Remove obsolete files
	rm *.html
else
	
#######################################################
# GET master properties from BOOTSTRAP_MASTER_HOST
# GET replica properties from BOOTSTRAP_REPLICA_HOST
# POST master properties to BOOTSTRAP_REPLICA_HOST
# POST replica properties to BOOTSTRAP_MASTER_HOST
#   (1) GET /manage/v2/properties (master-host)
#   (2) GET /manage/v2/properties (replica-host)
#   (3) POST /manage/v2/clusters (master-host)
#   (4) POST /manage/v2/clusters (replica-host)

  echo "Coupling master cluster to replica cluster"

  # (1) GET master properties from BOOTSTRAP_MASTER_HOST
  MASTER_PROPERTIES=`$AUTH_CURL -X GET -H "Content-Type:application/json" \
    http://${BOOTSTRAP_MASTER_HOST}:8002/manage/v2/properties?format=json`
#  echo $MASTER_PROPERTIES

  # (2) GET replica properties from BOOTSTRAP_REPLICA_HOST
  REPLICA_PROPERTIES=`$AUTH_CURL -X GET -H "Content-Type:application/json" \
    http://${BOOTSTRAP_REPLICA_HOST}:8002/manage/v2/properties?format=json`
#  echo $REPLICA_PROPERTIES

  # (3) POST /manage/v2/clusters (master-host)
  $AUTH_CURL -X POST -H "Content-Type:application/json" -d"$REPLICA_PROPERTIES" \
    http://${BOOTSTRAP_MASTER_HOST}:8002/manage/v2/clusters?format=json

  # (4) POST /manage/v2/clusters (replica-host)
  $AUTH_CURL -X POST -H "Content-Type:application/json" -d"$MASTER_PROPERTIES" \
    http://${BOOTSTRAP_REPLICA_HOST}:8002/manage/v2/clusters?format=json
fi

echo "...$BOOTSTRAP_MASTER_HOST successfully coupled to BOOTSTRAP_REPLICA_HOST."
