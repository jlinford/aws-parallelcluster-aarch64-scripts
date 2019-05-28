#!/bin/bash


function parse_args {
  if [ $# -lt 3 ] ; then
    echo "Usage: $0 s3_motd s3_aas_license num_users [uname_tmpl] [passwd_tmpl]"
    exit -1
  fi

  S3_MOTD="$1"
  S3_AAS_LICENSE="$2"
  NUSERS="$3"
  UNAME_BASE="${4:-student}"
  PASSWD_BASE="${5:-Tr@ining}"
}

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

function install_motd {
  # AWS ParallelCluster enables access via s3_read_resource
  aws s3 cp "$S3_MOTD" "/etc/motd"
}


parse_args
create_users
install_aas_license
install_motd

