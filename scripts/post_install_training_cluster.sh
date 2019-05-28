#!/bin/bash
#
# John Linford <john.linford@arm.com>
#

UNAME_BASE="student"
PASSWD_BASE="Tr@ining"

if [ $# -lt 3 ] ; then
  echo "Usage: $0 script_name s3_aas_license num_users [training_url]"
  exit -1
fi
SCRIPT_NAME="$1"
S3_AAS_LICENSE="$2"
NUSERS="$3"
TRAINING_URL="$4"

# Create user accounts
for i in $(seq -f "%03g" 1 $NUSERS) ; do
  user_name="${UNAME_BASE}$i"
  useradd -K UID_MIN=2000 -m "$user_name"
  echo "${PASSWD_BASE}$i" | passwd --stdin "$user_name"
done

# Enable password-based SSH
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i -e 's/PasswordAuthentication/#PasswordAuthentication/g' "$SSHD_CONFIG"
echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
systemctl restart sshd

# Install AAS license
aws s3 cp "$S3_AAS_LICENSE" "/opt/arm/licenses/license"

# Install MOTD
cat > /etc/motd <<"EOF"
                            _    _ _____   _____
     /\                    | |  | |  __ \ / ____|
    /  \   _ __ _ __ ___   | |__| | |__) | |
   / /\ \ | '__| '_ ` _ \  |  __  |  ___/| |
  / ____ \| |  | | | | | | | |  | | |    | |____
 /_/    \_\_|  |_| |_| |_| |_|  |_|_|     \_____|

EOF

# Add training URL to MOTD
if [ ! -z "$TRAINING_URL" ] ; then 
  echo "Training materials:" >> /etc/motd
  echo "$TRAINING_URL" >> /etc/motd
fi

