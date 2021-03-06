assign_eip
==========

Assign AWS Elastic IP address to the instance.

This script will take over an Elastic IP (defined by EIP_ALLOC number) to the instance
this script is running on.

The purpose is to use this script for RHEL/CentOS Cluster failover facility.

This script is based on vip_monitor.sh (http://media.amazonwebservices.com/articles/vip_monitor_files/vip_monitor.sh) from https://aws.amazon.com/articles/2127188135977316

Requirements
============

- openjdk
- ec2-api-tools

Configuration
=============
- Modify /etc/profile.d/ec2-api.sh:
~~~
export AWS_ELB_HOME=/opt/ec2-api-tools
export EC2_HOME=/opt/ec2-api-tools
export PATH=$PATH:$EC2_HOME/bin
source /etc/java/java.conf
~~~

- Set up JAVA_HOME in /etc/java/java.conf and export all variables:
~~~
export JAVA_LIBDIR=/usr/share/java
export JNI_LIBDIR=/usr/lib/java
export JVM_ROOT=/usr/lib/jvm
export JAVA_HOME=$JVM_ROOT/jre
export JAVACMD_OPTS=
~~~

- Create /etc/sysconfig/assign_eip and put EIP_ALLOC and REGION variables into it:
~~~
EIP_ALLOC=eipalloc-000000
REGION=us-east-1
~~~

- Make sure your instance has appropriate IAM role policy set up:
~~~ 
{
  "Statement": [
    {
      "Action": [
        "ec2:AssociateAddress",
        "ec2:DescribeAddresses",
        "ec2:DescribeInstances",
        "ec2:DescribeTags",
        "ec2:RebootInstances",
        "ec2:StartInstances",
        "ec2:StopInstances"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
~~~

- Configure failover in RH Cluster (/etc/cluster/cluster.conf):
~~~
<?xml version="1.0"?>
<cluster config_version="1" name="mycluster">
        <clusternodes>
                <clusternode name="node1-ip" nodeid="1"/>
                <clusternode name="node2-ip" nodeid="2"/>
        </clusternodes>
        <cman expected_votes="1" transport="udpu" two_node="1"/>
        <rm>
                <resources>
                        <script file="/usr/local/bin/assign_eip.sh" name="Assign EIP"/>
                </resources>
                <failoverdomains>
                        <failoverdomain name="mycluster" nofailback="1">
                                <failoverdomainnode name="node1-ip"/>
                                <failoverdomainnode name="node2-ip"/>
                        </failoverdomain>
                </failoverdomains>
                <service domain="mycluster" name="All" recovery="relocate">
                        <script ref="Assign EIP" />
                </service>
        </rm>
        <fence_daemon skip_undefined="1"/>
        <logging>
                <logging_daemon debug="on" name="rgmanager" syslog_priority="debug" to_logfile="no"/>
        </logging>
</cluster>
~~~
