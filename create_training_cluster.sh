#!/bin/bash
#
# John Linford <john.linford@arm.com>
#

DEFAULT_KEY_NAME="jcl"
DEFAULT_VPC_ID="vpc-b1fb0bd4"
DEFAULT_MASTER_SUBNET_ID="subnet-95be6cf0"
DEFAULT_CLUSTER_SIZE=20

CUSTOM_AMI="ami-06f5438d5563336f4"
CUSTOM_COOKBOOK="https://s3.eu-west-1.amazonaws.com/com.arm.cluster/cookbooks/aws-parallelcluster-cookbook-2.4.0.tgz"
COMPUTE_INSTANCE_TYPE="a1.large"
MASTER_INSTANCE_TYPE="a1.xlarge"

declare -a TEMP_FILES

function cleanup {
  for tempfile in ${TEMP_FILES[@]} ; do
    rm -f "$tempfile"
  done
}
#trap cleanup exit 

function make_temp {
  dest="$1"
  tempfile=`mktemp`
  TEMP_FILES+=("$tempfile")
  eval $dest="$tempfile"
}

function input_line {
  prompt="$1"
  dest="$2"
  default="$3"
  if [ -z "$default" ] ; then
    prompt="$prompt: "
  else
    prompt="$prompt [$default]: "
  fi
  while true ; do
    read -p "$prompt" line
    line="${line:-$default}"
    if ! [ -z "$line" ] ; then
      break
    fi
  done
  eval $dest="$line"
}

function _get_aws_object {
  ec2_cmd="$1"
  collection="$2"
  attribute="$3"
  predicate="$4"
  prompt="$5"
  dest="$6"
  all_obj=()
  for obj in `aws ec2 ${ec2_cmd} | python -c "import sys, json; [print(obj[\"$attribute\"]) for obj in json.load(sys.stdin)[\"$collection\"] if $predicate]"` ; do
    all_obj+=("$obj")
  done
  for obj in ${all_obj[@]} ; do
    echo "  $obj"
  done
  input_line "$prompt" "$dest" "${all_obj[0]}"
}


function get_key_pair {
  echo "Available key pairs:"
  _get_aws_object "describe-key-pairs" "KeyPairs" "keyName" "True" "Key Name" KEY_NAME
}

function get_subnet {
  echo "Available VPCs:"
  _get_aws_object "describe-vpcs" "Vpcs" "VpcId" "True" "VPC ID" VPC_ID
  echo "Available subnets:"
  _get_aws_object "describe-subnets" "Subnets" "SubnetId" "obj[\"VpcId\"] == \"$VPC_ID\"" "Subnet" SUBNET_ID
}

# Get AWS region and credentials
input_line "AWS Region" AWS_DEFAULT_REGION "$AWS_DEFAULT_REGION"
input_line "AWS Access Key ID" AWS_ACCESS_KEY_ID "$AWS_ACCESS_KEY_ID"
input_line "AWS Secret Access Key" AWS_SECRET_ACCESS_KEY "$AWS_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION
export AWS_ACCESS_KEY_ID 
export AWS_SECRET_ACCESS_KEY

# Get cluster config
input_line "New Cluster Name" CLUSTER_NAME
echo "Each student has their own compute node, so cluster size is both the "
echo "number of compute nodes and the number of student accounts."
input_line "New Cluster Size" CLUSTER_SIZE "$DEFAULT_CLUSTER_SIZE"
get_aws_key 
get_subnet

# Write config
make_temp CONFIG_FILE
echo $CONFIG_FILE
cat > "$CONFIG_FILE" <<EOF
[global]
cluster_template = training_cluster
# We're hacking. Freeze the version.
update_check = false
# Workaround: running on aarch64 is insane
sanity_check = false

[aws]
aws_region_name = $AWS_DEFAULT_REGION

[vpc public]
vpc_id = $VPC_ID
master_subnet_id = $SUBNET_ID

[cluster training_cluster]
key_name = $KEY_NAME
vpc_settings = public
s3_read_resource = arn:aws:s3:::com.arm.cluster/*
# Lower and upper bounds on compute node instances
initial_queue_size = $CLUSTER_SIZE
max_queue_size = 100
# aarch64 support
custom_ami = $CUSTOM_AMI
custom_chef_cookbook = $CUSTOM_COOKBOOK
compute_instance_type = $COMPUTE_INSTANCE_TYPE
master_instance_type = $MASTER_INSTANCE_TYPE
# Workaround: aarch64 volumes must be at least 100GB
master_root_volume_size = 1000
compute_root_volume_size = 100
# Workaround: SGE didn't work on aarch64 so use slurm
scheduler = slurm
scaledown_idletime = 480
# Workaround: https://github.com/aws/aws-parallelcluster/issues/341
maintain_initial_size = true
EOF

# Launch
pcluster create -c "$CONFIG_FILE" "$CLUSTER_NAME"

