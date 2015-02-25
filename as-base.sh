# Basic Environment
GRADING_HOME=$HOME
S3_BUCKET=progfun-coursera

CLUSTER_NAME=`cat $GRADING_HOME/clusterName`
[[ -z $CLUSTER_NAME ]] && echo "Cluster name must be specified in the file $GRADING_HOME/clusterName." && exit 1

function clusterPrefixed () {
  echo "$CLUSTER_NAME-$1"
}

s3base="$GRADING_HOME/s3data"
s3dir="$s3base/$CLUSTER_NAME"
settingsDir="$s3dir/settings"
coursesDir="$s3dir/courses"

# Zones
ZONES="us-east-1a,us-east-1b,us-east-1c,us-east-1d"

# Names
MASTER_LC=$(clusterPrefixed "masterLC")
LC=$(clusterPrefixed "courseraLC")
BACKUP_LC=$(clusterPrefixed "courseraBackupLC")
MASTER_ASG=$(clusterPrefixed "masterASG")
ASG=$(clusterPrefixed "courseraASG")
BACKUP_ASG=$(clusterPrefixed "courseraBackupASG")

# Images
MASTER_IMAGE="ami-a6590ace"
WORKER_IMAGE="ami-508cdc38"

# Scaling Params
MASTER_TYPE="t1.micro"
INSTANCE_TYPE="c3.large"
INSTANCE_TYPE2="m3.large"
NUMBER_OF_GRADERS="3" # Number of graders should be nr_of_cores + 1
MAX_SIZE=30

# Values depend on how fast are the machines
UP_ADJ="1"
DOWN_ADJ="-1"
BACKUP_UP_ADJ="2"
BACKUP_DOWN_ADJ="-1"

UPPER_UTILIZATION_THRESHOLD="90"
LOWER_UTILIZATION_THRESHOLD="70"

UPPER_WAITING_TIME_THERSHOLD="300"
LOWER_WAITING_TIME_THERSHOLD="50"
UPPER_WAITING_TIME_THERSHOLD2="600"
LOWER_WAITING_TIME_THERSHOLD2="300"

# Utils
# Preventing eventual consistency issues
SLEEP_TIME=60
