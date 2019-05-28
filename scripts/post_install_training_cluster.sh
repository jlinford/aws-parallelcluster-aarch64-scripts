#!/bin/bash
#
# John Linford <john.linford@arm.com>
#

if [ $# -lt 2 ] ; then
  echo "Usage: $0 s3_aas_license num_users [training_url]"
  exit -1
fi
S3_AAS_LICENSE="$1"
NUSERS="$2"
TRAINING_URL="$3"
UNAME_BASE="student"
PASSWD_BASE="Tr@ining"


function create_users {
  # Create user accounts
  for i in $(seq -f "%03g" 1 $NUSERS) ; do
    user_name="${UNAME_BASE}$i"
    useradd -K UID_MIN=2000 -m "$user_name"
    echo "${PASSWD_BASE}$i" | passwd --stdin "$user_name"
  done

  exit

  # Enable password-based SSH
  SSHD_CONFIG="/etc/ssh/sshd_config"
  sed -i -e 's/PasswordAuthentication/#PasswordAuthentication/g' "$SSHD_CONFIG"
  echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
  systemctl restart sshd
}

function install_aas_license {
  # AWS ParallelCluster enables access via s3_read_resource
  aws s3 cp "$S3_AAS_LICENSE" "/opt/arm/licenses/license"
}

function update_motd {
  if [ ! -z "$TRAINING_URL" ] ; then 
    echo "Training materials available at:" >> /etc/motd
    echo "$TRAINING_URL" >> /etc/motd
  fi
}

create_users
install_aas_license
update_motd


