#!/bin/sh
#
# This script will take over an Elastic IP (defined by EIP_ALLOC number) to the instance
# this script is running on.
# The purpose is to use this script for RedHat Cluster failover facility.
#

# Elastic IP ID
EIP_ALLOC=eipalloc-0123456

# Specify the EC2 region that this will be running in
REGION=us-east-1

# Run aws-apitools-common.sh to set up default environment variables and to
# leverage AWS security credentials provided by EC2 roles
. /etc/profile.d/ec2-api.sh

# Determine the instance and ENI IDs so we can reassign the EIP to the
# correct ENI.  Requires EC2 describe-instances and assign-private-ip-address
# permissions.  The following example EC2 Roles policy will authorize these
# commands:
# {
#  "Statement": [
#    {
#      "Action": [
#        "ec2:AssociateAddress",
#        "ec2:DescribeAddresses",
#        "ec2:DescribeInstances",
#        "ec2:DescribeTags",
#         "ec2:RebootInstances",
#         "ec2:StartInstances",
#        "ec2:StopInstances"
#      ],
#      "Effect": "Allow",
#      "Resource": "*"
#    }
#  ]
# }

# source function library
. /etc/rc.d/init.d/functions

RETVAL=0

start() {
        echo -n $"Starting EIP association..."

        Instance_ID=`/usr/bin/curl --silent http://169.254.169.254/latest/meta-data/instance-id`
        ENI_ID=`/opt/ec2-api-tools/bin/ec2-describe-instances $Instance_ID --region $REGION | grep eni -m 1 | awk '{print $2;}'`

        MAC=`/usr/bin/curl --silent http://169.254.169.254/latest/meta-data/mac`
        PRI_IP=`/usr/bin/curl --silent http://169.254.169.254/latest/meta-data/local-ipv4`
        SEC_IP=`/usr/bin/curl --silent http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/local-ipv4s | grep -v $PRI_IP`

        /opt/ec2-api-tools/bin/ec2-associate-address -a $EIP_ALLOC -n $ENI_ID -p $SEC_IP --allow-reassociation | grep -q ADDRESS && success || failure
        echo
}

stop () {
        echo -n $"Stoppoing EIP association... " && success
        echo
}

status() {
        EIP=`/opt/ec2-api-tools/bin/ec2-describe-addresses eipalloc-42835827 | grep ADDRESS | awk '{print $2}'`
        MAC=`/usr/bin/curl --silent http://169.254.169.254/latest/meta-data/mac`
        /usr/bin/curl --silent http://169.254.169.254/latest/meta-data/network/interfaces/macs/$MAC/public-ipv4s | grep -q $EIP
        ISASSIGNED=$?

        [ "x$ISASSIGNED" = "x1" ] && echo "EIP is not assigned" && return 1

        echo "EIP is $EIP" && return 0
}

# See how we were called.
case "$1" in
        start)
                start
                ;;
        stop)
                stop
                ;;
        status)
                status
                RETVAL=$?
                ;;
        restart)
                stop
                start
                ;;
        *)
                echo $"Usage: $PROG {start|stop|restart|status|help}"
                exit 1
esac

exit $RETVAL
