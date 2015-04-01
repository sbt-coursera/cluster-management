# Environment from the image file system.
GRADING_HOME=$HOME
CLUSTER_NAME=`cat $GRADING_HOME/clusterName`
[[ -z $CLUSTER_NAME ]] && echo "Cluster name must be specified in the file $GRADING_HOME/clusterName." && exit 1
S3_BUCKET=`cat $GRADING_HOME/s3Bucket`
[[ -z $S3_BUCKET ]] && echo "S3 bucket must be specified in the file $GRADING_HOME/s3Bucket." && exit 1

s3base="$GRADING_HOME/s3data"
s3dir="$s3base/$CLUSTER_NAME"
settingsDir="$s3dir/settings"
coursesDir="$s3dir/courses"

# Verify the S3 dir presence.
[[ -e $settingsDir ]] || s3fs $S3_BUCKET $s3base
[[ -e $settingsDir ]] || {
  echo "The S3 directory is not mounted since $settingsDir does not exist. Exiting script..."
  sns-publish-coursera --message "" --subject "Coursera: Settings dir is not visible."
}

function clusterPrefixed () {
  echo "$CLUSTER_NAME-$1"
}

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
MASTER_IMAGE=`cat $settingsDir/masterImage`
WORKER_IMAGE=`cat $settingsDir/workerImage`

# Scaling Params
MASTER_TYPE=`cat $settingsDir/masterType`
INSTANCE_TYPE=`cat $settingsDir/workerType`
INSTANCE_TYPE2=`cat $settingsDir/workerType2`
NUMBER_OF_GRADERS=`cat $settingsDir/workersPerMachine`
NOTIFICATION_ARN=`cat $settingsDir/notificationARN`

MAX_SIZE=30

# Values depend on how fast are the machines
UP_ADJ="1"
DOWN_ADJ="-1"
# 2 since this scaling group is supposed to save the day
BACKUP_UP_ADJ="2"
BACKUP_DOWN_ADJ="-1"

# do not go above 85 as it happens that the cluster will not scale up althoug utilized
UPPER_UTILIZATION_THRESHOLD="85"
LOWER_UTILIZATION_THRESHOLD="70"

UPPER_WAITING_TIME_THERSHOLD="300"
LOWER_WAITING_TIME_THERSHOLD="50"

# Utils
# Preventing eventual consistency issues
SLEEP_TIME=90
