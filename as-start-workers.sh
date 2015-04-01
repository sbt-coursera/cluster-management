#!/bin/bash -x
source `dirname $0`/as-base.sh

as-create-launch-config $LC --image-id $WORKER_IMAGE --instance-type $INSTANCE_TYPE  --key coursera
as-create-launch-config $BACKUP_LC --image-id $WORKER_IMAGE --instance-type $INSTANCE_TYPE2 --key coursera

sleep $SLEEP_TIME
as-create-auto-scaling-group $ASG --launch-configuration $LC --availability-zones $ZONES --min-size 1 --max-size $MAX_SIZE --default-cooldown 300  --termination-policies "ClosestToNextInstanceHour"
as-create-auto-scaling-group $BACKUP_ASG --launch-configuration $BACKUP_LC --availability-zones $ZONES --min-size 0 --max-size $MAX_SIZE --default-cooldown 300  --termination-policies "ClosestToNextInstanceHour"

sleep $SLEEP_TIME
scaleUpPolicyARN=`as-put-scaling-policy $(clusterPrefixed "courseraScaleUpPolicy") --auto-scaling-group $ASG --adjustment $UP_ADJ --type ChangeInCapacity --cooldown 240`
scaleDownPolicyARN=`as-put-scaling-policy $(clusterPrefixed "courseraScaleDownPolicy") --auto-scaling-group $ASG --adjustment=$DOWN_ADJ --type ChangeInCapacity --cooldown 1200`
backupScaleUpPolicyARN=`as-put-scaling-policy $(clusterPrefixed "courseraBackupScaleUpPolicy") --auto-scaling-group $BACKUP_ASG --adjustment $BACKUP_UP_ADJ --type ChangeInCapacity --cooldown 240`
backupScaleDownPolicyARN=`as-put-scaling-policy $(clusterPrefixed "courseraBackupScaleDownPolicy") --auto-scaling-group $BACKUP_ASG --adjustment=$BACKUP_DOWN_ADJ --type ChangeInCapacity --cooldown 240`

sleep $SLEEP_TIME
# Trigger 1 - Based on utilization (normal mode of operation)
mon-put-metric-alarm --alarm-name $(clusterPrefixed "courseraUtilizationScaleUpAlarm")    --namespace "AWS/EC2" --metric-name CPUUtilization --dimensions "AutoScalingGroupName=$ASG" --statistic Average --threshold $UPPER_UTILIZATION_THRESHOLD --comparison-operator GreaterThanThreshold --period 120 --evaluation-periods 5 --unit Percent --alarm-actions $scaleUpPolicyARN
mon-put-metric-alarm --alarm-name $(clusterPrefixed "courseraUtilizationScaleDownAlarm")  --namespace "AWS/EC2" --metric-name CPUUtilization --dimensions "AutoScalingGroupName=$ASG" --statistic Average --threshold $LOWER_UTILIZATION_THRESHOLD --comparison-operator LessThanThreshold --period 120 --evaluation-periods 5 --unit Percent --alarm-actions  $scaleDownPolicyARN

# Backup - This metric should fire if the WaitingTime goes above a threshold.
[[ -z $NOTIFICATION_ARN ]] || {
  mon-put-metric-alarm --alarm-name $(clusterPrefixed "backupMessageAlarm")         --namespace $CLUSTER_NAME --metric-name WaitingTime --statistic Average --threshold $UPPER_WAITING_TIME_THERSHOLD --comparison-operator GreaterThanThreshold --period 120 --evaluation-periods 5 --alarm-actions $NOTIFICATION_ARN
}
mon-put-metric-alarm --alarm-name $(clusterPrefixed "courseraBackupScaleUpAlarm")   --namespace $CLUSTER_NAME --metric-name WaitingTime --statistic Average --threshold $UPPER_WAITING_TIME_THERSHOLD --comparison-operator GreaterThanThreshold --period 120 --evaluation-periods 5 --alarm-actions $backupScaleUpPolicyARN
mon-put-metric-alarm --alarm-name $(clusterPrefixed "courseraBackupScaleDownAlarm") --namespace $CLUSTER_NAME --metric-name WaitingTime --statistic Average --threshold $LOWER_WAITING_TIME_THERSHOLD --comparison-operator LessThanThreshold --period 120 --evaluation-periods 5 --alarm-actions $backupScaleDownPolicyARN
