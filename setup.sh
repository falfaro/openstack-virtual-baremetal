#/bin/bash

function create_glance_image() {
  image_name=$1
  image_file=$2
  if [ -n "$3" ]; then
    image_property="--property $3"
  fi
  echo Creating Glance image $image_name...
  if ! glance image-list | grep $image_name >/dev/null; then
    glance image-create --name $image_name --disk-format qcow2 $image_property --container-format bare --progress --file $image_file
  fi
}

function download_image() {
  image_url="$1"
  image_file="$(basename $1)"
  if [ ! -f "$image_file" ]; then
    wget "$image_url"
  fi
}

function create_nova_flavor() {
  flavor_name="$1"
  flavor_ram_mb="$2"
  flavor_disk_gb="$3"
  flavor_cpu="$4"
  echo Creating Nova flavor $flavor_name...
  if ! nova flavor-show $flavor_name >/dev/null 2>&1; then
    nova flavor-create $flavor_name auto $flavor_ram_mb $flavor_disk_gb $flavor_cpu
  fi
}

function create_nova_keypair() {
  echo Creating default Nova keypair...
  if ! nova keypair-show default >/dev/null 2>&1; then
    nova keypair-add --pub-key ~/.ssh/id_rsa.pub default
  fi
}

download_image http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
download_image https://repos.fedorapeople.org/repos/openstack-m/ovb/bmc-base.qcow2
create_glance_image ipxe-boot ipxe/ipxe-boot.qcow2 os_shutdown_timeout=5
create_glance_image CentOS-7-x86_64-GenericCloud CentOS-7-x86_64-GenericCloud.qcow2
create_glance_image bmc-base bmc-base.qcow2
create_nova_flavor bmc 512 20 1
create_nova_flavor baremetal 4096 20 2
create_nova_flavor undercloud 8192 30 4
create_nova_keypair

neutron quota-update --security_group 1000
neutron quota-update --port -1
neutron quota-update --network -1
neutron quota-update --subnet -1
openstack quota set --ram -1 --cores -1 --instances -1 admin

echo
echo NOTE: Now, run bin/deploy.py --quintupleo --poll
echo
