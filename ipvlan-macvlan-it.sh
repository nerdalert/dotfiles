#!/bin/sh
#
# Temp IT testing to be run against ipvlan/macvlan drivers without failure.
# Notes at: https://gist.github.com/nerdalert/c0363c15d20986633fda
#
# Change eth0 to the link to be used for the `-o host_iface=`
ETH=${ETH:-eth0}
EXPECTED_NETWORKS=34
EXPECTED_CONTAINERS=67

command_exists() {
  command -v "$@" > /dev/null 2>&1
}

# Ensure docker is running
check_setup() {
  if command_exists if command_exists sudo ps -ef | grep docker | awk '{print $2}' && [ -e /var/run/docker.sock ]; then
    (set -x $dk '"Docker has been installed"') || true
    echo "PASS ----->  Docker daemon instance found"
  else
    echo "FAIL ----->  A running Docker daemon was not found, start Docker with 'docker daemon -D'"
    exit 1
  fi
  LINK_EXISTS=`grep ${ETH} /proc/net/dev`
  if  [ -n "$LINK_EXISTS" ] ; then
    echo "PASS ----->  Detected valid interface:[ ${ETH} ] to run the tests."
  else
    echo "FAIL ----->  [ ${ETH} ] device was not found on this host. Specify the interface you wish to use as the macvlan/ipvlan -o host_interface by setting the 'ETH' variable in the script"
    exit 1
  fi
  echo 'WARN ----->  Prior to the test, the script will now ensure there are no Docker networks named [ ipnet ] or [ macnet ]'
  echo 'WARN ----->  To abort deleting those Docker networks hit ctrl^c within the next 5 seconds..'
  sleep 5
  cleanup
}


verify_results() {
  LINK_COUNT=$(ip link | grep @${ETH} | wc -l)
  ACTUAL_NETWORKS=$(docker network ls | grep "macvlan\|ipvlan" | wc -l)
  ACTUAL_CONTAINERS=$(docker ps | grep "debian\|alpine" | wc -l)
  echo "#########################################################################################"
  # The results should be 34 networks created
  if [ ${ACTUAL_NETWORKS} -eq ${EXPECTED_NETWORKS} ]
  then
    echo "PASS ---------> Macvlan/Ipvlan drivers created the proper number of networks:[ ${ACTUAL_NETWORKS} ]"
    echo "PASS ---------> Macvlan/Ipvlan number of Links exist:[ ${LINK_COUNT} ] ('ip link')"
  else
    echo "FAILED ---------> Macvlan/Ipvlan drivers created the wrong number of networks:[ ${ACTUAL_NETWORKS} ] shoul
    d have been [ $EXPECTED_NETWORKS ]"
    echo "FAILED ---------> Macvlan/Ipvlan number of Links exist:[ ${LINK_COUNT} ] ('ip link')"
  fi
  # The container account should be
  if [ ${ACTUAL_CONTAINERS} -eq ${EXPECTED_CONTAINERS} ]
  then
    echo "PASS ---------> Macvlan/Ipvlan drivers created the proper number of containers:[ ${ACTUAL_CONTAINERS} ]"
  else
    echo "FAILED ---------> Macvlan/Ipvlan drivers created the wrong number of containers:[ ${ACTUAL_CONTAINERS} ] shoul
    d have been [ $EXPECTED_CONTAINERS ]"
  fi
  echo "#########################################################################################"

}

run() {
  echo 'INFO -----> The following test will create a series of Mavlan and Ipvlan networks and containers'
  echo 'INFO -----> After completing the tests, the containers and networks will then be deleted.'
  echo 'INFO -----> If you wish to view the containers and networks, hit ctrl^c when prompted to break the script before cleanup'
  echo 'INFO -----> Beginning network and container creations in 5 seconds..'
  sleep 5
  #    set -x # activate debugging from here
  ################################################################################
  # Macvlan Bridge Mode IPv4 802.1q VLAN Tagged Tests
  #
  ### Network macvlan with --ip-range
  docker network create -d macvlan  \
  --subnet=192.168.32.0/24  \
  --ip-range=192.168.32.128/25 \
  --gateway=192.168.32.254  \
  -o host_iface=${ETH}.32 macnet32
  ### Network w/o explicit mode to default to -o macvlan_mode=bridge VLAN ID:33
  docker network create -d macvlan  \
  --subnet=192.168.33.0/24  \
  --gateway=192.168.33.1  \
  -o host_iface=${ETH}.33 macnet33
  ### Network w/o explicit macvlan_mode=(defaults to bridge)
  docker network create -d macvlan  \
  --subnet=192.168.34.0/24  \
  --gateway=192.168.34.1  \
  -o host_iface=${ETH}.34 macnet34
  ### Network with a GW: ,254 & VLAN ID:35
  docker network create -d macvlan  \
  --subnet=192.168.35.0/24  \
  --gateway=192.168.35.254  \
  -o host_iface=${ETH}.35 macnet35
  ### Network w/o explicit --gateway=(libnetqork ipam defaults to .1)
  docker network create -d macvlan  \
  --subnet=192.168.36.0/24  \
  -o host_iface=${ETH}.36  \
  -o macvlan_mode=bridge macnet36
  ### Network w/ GW: .254, w/o explicit --macvlan_mode
  docker network create -d macvlan  \
  --subnet=192.168.37.0/24  \
  --gateway=192.168.37.254  \
  -o host_iface=${ETH}.37  \
  -o macvlan_mode=bridge macnet37
  ### No Gateway specified test (defaults to x.x.x.1 as a gateway)
  docker network create -d macvlan  \
  --subnet=192.168.38.0/24  \
  -o host_iface=${ETH}.38  \
  -o macvlan_mode=bridge macnet38
  ### No Gateway specified test (defaults to x.x.x.1 as a gateway)
  docker network create -d macvlan  \
  --subnet=192.168.39.0/24  \
  -o host_iface=${ETH}.39  \
  -o macvlan_mode=bridge macnet39
  ### Start containers on each network
  docker run --net=macnet32 --name=macnet32_test -itd alpine /bin/sh
  docker run --net=macnet33 --name=macnet33_test -itd alpine /bin/sh
  docker run --net=macnet34 --name=macnet34_test -itd alpine /bin/sh
  docker run --net=macnet35 --name=macnet35_test -itd alpine /bin/sh
  docker run --net=macnet36 --name=macnet36_test -itd alpine /bin/sh
  ### Start containers with explicit --ip4 addrs
  docker run --net=macnet37 --name=macnet37_test --ip=192.168.37.10 -itd alpine /bin/sh
  docker run --net=macnet38 --name=macnet38_test --ip=192.168.38.10 -itd alpine /bin/sh
  docker run --net=macnet39 --name=macnet39_test --ip=192.168.39.10 -itd alpine /bin/sh
  ################################################################################
  # Ipvlan L2 Mode IPv4 802.1q VLAN Tagged Tests
  #
  #
  ### Network with --ip-range
  docker network create -d macvlan  \
  --subnet=192.168.42.0/24  \
  --ip-range=192.168.42.128/25 \
  --gateway=192.168.42.254  \
  -o host_iface=${ETH}.42 ipnet42
  ### Network w/o explicit mode to default to -o ipvlan_mode=l2 VLAN ID:43
  docker network create -d ipvlan  \
  --subnet=192.168.43.0/24  \
  --gateway=192.168.43.1  \
  -o host_iface=${ETH}.43 ipnet43
  ### Network w/o explicit ipvlan_mode=(defaults to l2 if unspecified)
  docker network create -d ipvlan  \
  --subnet=192.168.44.0/24  \
  --gateway=192.168.44.1  \
  -o host_iface=${ETH}.44 ipnet44
  ### Network with a GW: ,254 & VLAN ID:45
  docker network create -d ipvlan  \
  --subnet=192.168.45.0/24  \
  --gateway=192.168.45.254  \
  -o host_iface=${ETH}.45 ipnet45
  ### Network w/o explicit --gateway=(libnetqork ipam defaults to .1)
  docker network create -d ipvlan  \
  --subnet=192.168.46.0/24  \
  -o host_iface=${ETH}.46  \
  -o ipvlan_mode=l2 ipnet46
  ### Network w/ GW: .254, w/o explicit --ipvlan_mode
  docker network create -d ipvlan  \
  --subnet=192.168.47.0/24  \
  --gateway=192.168.47.254  \
  -o host_iface=${ETH}.47  \
  -o ipvlan_mode=l2 ipnet47
  ### No Gateway specified test (defaults to x.x.x.1 as a gateway)
  docker network create -d ipvlan  \
  --subnet=192.168.48.0/24  \
  -o host_iface=${ETH}.48  \
  -o ipvlan_mode=l2 ipnet48
  ### No Gateway specified test (defaults to x.x.x.1 as a gateway)
  docker network create -d ipvlan  \
  --subnet=192.168.49.0/24  \
  -o host_iface=${ETH}.49  \
  -o ipvlan_mode=l2 ipnet49
  ### Network with --ip-range
  docker network create -d ipvlan  \
  --subnet=192.168.40.0/24  \
  --ip-range=192.168.40.128/25 \
  --gateway=192.168.40.254  \
  -o host_iface=${ETH}.40 ipnet40
  ### Start containers on each network
  docker run --net=ipnet42 --name=ipnet42_test -itd alpine /bin/sh
  docker run --net=ipnet43 --name=ipnet43_test -itd alpine /bin/sh
  docker run --net=ipnet44 --name=ipnet44_test -itd alpine /bin/sh
  docker run --net=ipnet45 --name=ipnet45_test -itd alpine /bin/sh
  docker run --net=ipnet46 --name=ipnet46_test -itd alpine /bin/sh
  ### Start containers with explicit --ip4 addrs
  docker run --net=ipnet47 --name=ipnet47_test --ip=192.168.47.10 -itd alpine /bin/sh
  docker run --net=ipnet48 --name=ipnet48_test --ip=192.168.48.10 -itd alpine /bin/sh
  docker run --net=ipnet49 --name=ipnet49_test --ip=192.168.49.10 -itd alpine /bin/sh
  ################################################################################
  # Ipvlan L3 Mode IPv4 802.1q VLAN Tagged Tests
  #
  #
  ### Gateway is always ignored in L3 mode - default is 'default dev eth(n)'
  docker network create -d ipvlan  \
  --subnet=192.168.53.0/24  \
  --gateway=192.168.53.1  \
  -o ipvlan_mode=l3 \
  -o host_iface=${ETH}.53 ipnet53
  ### Network w/o --ip-range
  docker network create -d ipvlan  \
  --subnet=192.168.54.0/24  \
  --ip-range=192.168.54.128/25 \
  -o ipvlan_mode=l3 \
  -o host_iface=${ETH}.54 ipnet54
  ### Gateway is always ignored in L3 mode - default is 'default dev eth(n)'
  docker network create -d ipvlan  \
  --subnet=192.168.55.0/24  \
  --gateway=192.168.55.254  \
  -o ipvlan_mode=l3 \
  -o host_iface=${ETH}.55 ipnet55
  ### Network w/explicit mode set
  docker network create -d ipvlan  \
  --subnet=192.168.56.0/24  \
  -o host_iface=${ETH}.56  \
  -o ipvlan_mode=l3 ipnet56
  ### Gateway is always ignored in L3 mode - default is 'default dev eth(n)'
  docker network create -d ipvlan  \
  --subnet=192.168.57.0/24  \
  --gateway=192.168.57.254  \
  -o host_iface=${ETH}.57  \
  -o ipvlan_mode=l3 ipnet57
  ### Network w/ explicit mode specified
  docker network create -d ipvlan  \
  --subnet=192.168.58.0/24  \
  -o host_iface=${ETH}.58  \
  -o ipvlan_mode=l3 ipnet58
  ### Network w/ explicit mode specified
  docker network create -d ipvlan  \
  --subnet=192.168.59.0/24  \
  -o host_iface=${ETH}.59  \
  -o ipvlan_mode=l3 ipnet59
  ### Start containers on each network
  docker run --net=ipnet53 --name=ipnet53_test -itd alpine /bin/sh
  docker run --net=ipnet54 --name=ipnet54_test -itd alpine /bin/sh
  docker run --net=ipnet55 --name=ipnet55_test -itd alpine /bin/sh
  docker run --net=ipnet56 --name=ipnet56_test -itd alpine /bin/sh
  ### Start containers with explicit --ip4 addrs
  docker run --net=ipnet57 --name=ipnet57_test --ip=192.168.57.10 -itd alpine /bin/sh
  docker run --net=ipnet58 --name=ipnet58_test --ip=192.168.58.10 -itd alpine /bin/sh
  docker run --net=ipnet59 --name=ipnet59_test --ip=192.168.59.10 -itd alpine /bin/sh
  ################################################################################
  # Macvlan Multi-Subnet 802.1q VLAN Tagged Bridge Mode Tests
  #
  #
  ### Create multiple bridge subnets with a gateway of x.x.x.1:
  docker network create -d macvlan  \
  --subnet=192.168.64.0/24 --subnet=192.168.66.0/24  \
  --gateway=192.168.64.1 --gateway=192.168.66.1  \
  -o host_iface=${ETH}.64  \
  -o macvlan_mode=bridge macnet64
  ### Create multiple bridge subnets with a gateway of x.x.x.254:
  docker network create -d macvlan  \
  --subnet=192.168.65.0/24 --subnet=192.168.67.0/24  \
  --gateway=192.168.65.254 --gateway=192.168.67.254  \
  -o host_iface=${ETH}.65  \
  -o macvlan_mode=bridge macnet65
  ### Create multiple bridge subnets without a gateway (libnetwork IPAM will default to x.x.x.1):
  docker network create -d macvlan  \
  --subnet=192.168.70.0/24 --subnet=192.168.72.0/24  \
  -o host_iface=${ETH}.70  \
  -o macvlan_mode=bridge macnet70
  # Start Containers on network macnet64
  docker run --net=macnet64 --name=macnet64_test --ip=192.168.64.10 -itd alpine /bin/sh
  docker run --net=macnet64 --name=macnet66_test --ip=192.168.66.10 -itd alpine /bin/sh
  docker run --net=macnet64 --ip=192.168.64.11 -itd alpine /bin/sh
  docker run --net=macnet64 --ip=192.168.66.11 -itd alpine /bin/sh
  docker run --net=macnet64 -itd alpine /bin/sh
  # Start Containers on network macnet65
  docker run --net=macnet65 --name=macnet65_test --ip=192.168.65.10 -itd alpine /bin/sh
  docker run --net=macnet65 --name=macnet67_test --ip=192.168.67.10 -itd alpine /bin/sh
  docker run --net=macnet65 --ip=192.168.65.11 -itd alpine /bin/sh
  docker run --net=macnet65 --ip=192.168.67.11 -itd alpine /bin/sh
  docker run --net=macnet65 -itd alpine /bin/sh
  # Start Containers on  network macnet70
  docker run --net=macnet70 --name=macnet170_test --ip=192.168.70.10 -itd alpine /bin/sh
  docker run --net=macnet70 --name=macnet172_test --ip=192.168.72.10 -itd alpine /bin/sh
  docker run --net=macnet70 --ip=192.168.70.11 -itd alpine /bin/sh
  docker run --net=macnet70 --ip=192.168.72.11 -itd alpine /bin/sh
  docker run --net=macnet70 -itd alpine /bin/sh
  ################################################################################
  # Ipvlan Multi-Subnet 802.1q VLAN Tagged L3 Mode Tests
  #
  #
  ### Create multiple l3 mode subnets VLAN ID:104 (Gateway is ignored since L3 is always 'default dev eth0'):
  docker network create -d ipvlan  \
  --subnet=192.168.104.0/24 --subnet=192.168.106.0/24  \
  --gateway=192.168.104.1 --gateway=192.168.106.1  \
  -o ipvlan_mode=l3  \
  -o host_iface=${ETH}.104 ipnet104
  ### Create multiple l3 subnets w/ VLAN ID:104:
  docker network create -d ipvlan  \
  --subnet=192.168.105.0/24 --subnet=192.168.107.0/24  \
  -o host_iface=${ETH}.105  \
  -o ipvlan_mode=l3 ipnet105
  ### Create multiple l3 subnets w/ VLAN ID:110:
  docker network create -d ipvlan  \
  --subnet=192.168.110.0/24 --subnet=192.168.112.0/24  \
  -o host_iface=${ETH}.110  \
  -o ipvlan_mode=l3 ipnet110
  # Start Containers on the network ipnet104
  docker run --net=ipnet104 --name=ipnet104_test --ip=192.168.104.10 -itd alpine /bin/sh
  docker run --net=ipnet104 --name=ipnet106_test --ip=192.168.106.10 -itd alpine /bin/sh
  docker run --net=ipnet104 --ip=192.168.104.11 -itd alpine /bin/sh
  docker run --net=ipnet104 --ip=192.168.106.11 -itd alpine /bin/sh
  docker run --net=ipnet104 -itd alpine /bin/sh
  # Start Containers on the network ipnet105
  docker run --net=ipnet105 --name=ipnet105_test --ip=192.168.105.10 -itd alpine /bin/sh
  docker run --net=ipnet105 --name=ipnet107_test --ip=192.168.107.10 -itd alpine /bin/sh
  docker run --net=ipnet105 --ip=192.168.105.11 -itd alpine /bin/sh
  docker run --net=ipnet105 --ip=192.168.107.11 -itd alpine /bin/sh
  docker run --net=ipnet105 -itd alpine /bin/sh
  # Start Containers on the network ipnet110
  docker run --net=ipnet110 --name=ipnet110_test --ip=192.168.110.10 -itd alpine /bin/sh
  docker run --net=ipnet110 --name=ipnet112_test --ip=192.168.112.10 -itd alpine /bin/sh
  docker run --net=ipnet110 --ip=192.168.110.11 -itd alpine /bin/sh
  docker run --net=ipnet110 --ip=192.168.112.11 -itd alpine /bin/sh
  docker run --net=ipnet110 -itd alpine /bin/sh
  ################################################################################
  # Macvlan Bridge Mode V4/V6 Dual Stack Tests
  #
  #
  ### Create multiple ipv4 bridge subnets along with a ipv6 subnet
  ### Note ipv6 requires an explicit --gateway= in this case fe99::10
  docker network create -d macvlan  \
  --subnet=192.168.216.0/24 --subnet=192.168.218.0/24  \
  --gateway=192.168.216.1 --gateway=192.168.218.1  \
  --subnet=fe99::/64 --gateway=fe99::10  \
  -o host_iface=${ETH}.218  \
  -o macvlan_mode=bridge macnet216
  docker run --net=macnet216 --name=macnet216_test -itd debian
  docker run --net=macnet216 --name=macnet218_test -itd debian
  docker run --net=macnet216 --ip=192.168.216.11 -itd debian
  docker run --net=macnet216 --ip=192.168.218.11 -itd debian
  ################################################################################
  # Ipvlan Ipvlan L2 Mode V4/V6 Dual Stack Tests
  #
  #
  ### Create multiple ipv4 bridge subnets along with a ipv6 subnet
  ### Note ipv6 requires an explicit --gateway= in this case fe99::10
  docker network create -d ipvlan  \
  --subnet=192.168.213.0/24 --subnet=192.168.215.0/24  \
  --gateway=192.168.213.1 --gateway=192.168.215.1  \
  --subnet=fe97::/64 --gateway=fe97::10  \
  -o host_iface=${ETH}.213  \
  -o macvlan_mode=bridge ipnet213
  docker run --net=ipnet213 --name=ipnet213_test -itd debian
  docker run --net=ipnet213 --name=ipnet215_test -itd debian
  docker run --net=ipnet213 --ip=192.168.213.11 -itd debian
  docker run --net=ipnet213 --ip=192.168.215.11 -itd debian
  ################################################################################
  # Ipvlan L2 Mode V4/V6 Dual Stack Tests
  #
  #
  # Create an IPv6+IPv4 Dual Stack Ipvlan L3 network
  # Gateways for both v4 and v6 are set to a dev e.g. 'default dev eth0'
  docker network create -d ipvlan  \
  --subnet=192.168.131.0/24 --subnet=192.168.133.0/24  \
  --subnet=fe94::/64  \
  -o host_iface=${ETH}.131  \
  -o ipvlan_mode=l3 ipnet131
  # Start a container on the network
  # I use Debian here because how busybox iproute2 handles unreachable network output is funky
  docker run --net=ipnet131 -itd debian
  docker run --net=ipnet131 --ip6=fe94::10 -itd debian
  # Create an IPv6+IPv4 Dual Stack Ipvlan L3 network. Same example but verifying the --gateway= are ignored
  # Gateway/Nexthop is ignored in L3 mode and eth0 is used instead 'default dev eth0'
  docker network create -d ipvlan  \
  --subnet=192.168.119.0/24 --subnet=192.168.117.0/24  \
  --gateway=192.168.119.1 --gateway=192.168.117.1  \
  --subnet=fe96::/64 --gateway=fe96::27  \
  -o host_iface=${ETH}.117  \
  -o ipvlan_mode=l3 ipnet117
  # Start a container on the network
  # I use Debian here because how busybox iproute2 handles unreachable network output is funky
  docker run --net=ipnet117 -itd debian
  # Start a second container specifying the v6 address
  docker run --net=ipnet117 --ip6=fe96::10 -itd debian
  # Start a third specifying the IPv4 address
  docker run --net=ipnet117 --ip=192.168.117.50 -itd debian
  # Start a 4th specifying both the IPv4 and IPv6 addresses
  docker run --net=ipnet117 --ip6=fe96::50 --ip=192.168.119.50 -itd debian
  # stop debugging from here
  #    set +x
  echo ''
  echo 'INFO: ----->  All tests are completed'
  echo 'WARN ----->  Deleting ALL containers and networks the test created in 5 seconds'
  echo 'WARN ----->  Hit ctrl^c to abort if you want to view the created networks and links prior to deletion and rerun the script to clean them up.'
  sleep 5
}


cleanup() {
  echo 'WARN -----> Cleaning up all networks and links created by the tests..'
  docker rm -f `docker ps -qa` > /dev/null 2>&1
  echo 'WARN -----> Deleting all networks with names containing: ipnet'
  docker network rm $(docker network ls | grep ipnet | awk '{print $1}') > /dev/null 2>&1
  echo 'WARN -----> Deleting all networks with names containing: macnet'
  docker network rm $(docker network ls | grep macnet | awk '{print $1}') > /dev/null 2>&1
  echo 'INFO ----->  Completed deleting all Macvlan/Ipvlan networks and associated Links'
}

check_setup
run
verify_results
cleanup
echo "tests complete"
