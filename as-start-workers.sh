#!/bin/bash -x
source `dirname $0`/as-base.sh

as-create-launch-config $LC --image-id $WORKER_IMAGE --instance-type $INSTANCE_TYPE  --key coursera
as-create-launch-config $BACKUP_LC --image-id $WORKER_IMAGE --instance-type $INSTANCE_TYPE2 --key coursera

sleep $SLEEP_TIME
as-create-auto-scaling-group $ASG --launch-configuration $LC --availability-zones $ZONES --min-size 1 --max-size $MAX_SIZE --default-cooldown 300  --termination-policies "ClosestToNextInstanceHour"
as-create-auto-scaling-group $BACKUP_ASG --launch-configuration $BACKUP_LC --availability-zones $ZONES --min-size 0 --max-size $MAX_SIZE --default-cooldown 300  --termination-policies "ClosestToNextInstanceHour"

sleep $SLEEP_TIME
scaleUpPolicyARN=`as-put-scaling-policy courseraScaleUpPolicy --auto-scaling-group $ASG --adjustment $UP_ADJ --type ChangeInCapacity --cooldown 240`
scaleDownPolicyARN=`as-put-scaling-policy courseraScaleDownPolicy --auto-scaling-group $ASG --adjustment=$DOWN_ADJ --type ChangeInCapacity --cooldown 1200`
backupScaleUpPolicyARN=`as-put-scaling-policy courseraBackupScaleUpPolicy --auto-scaling-group $BACKUP_ASG --adjustment $BACKUP_UP_ADJ --type ChangeInCapacity --cooldown 240`
backupScaleDownPolicyARN=`as-put-scaling-policy courseraBackupScaleDownPolicy --auto-scaling-group $BACKUP_ASG --adjustment=$BACKUP_DOWN_ADJ --type ChangeInCapacity --cooldown 240`


sleep $SLEEP_TIME
# Trigger 1 - Utilization
mon-put-metric-alarm --alarm-name courseraUtilizationScaleUpAlarm --namespace "AWS/EC2" --metric-name CPUUtilization --dimensions "AutoScalingGroupName=courseraASG" --statistic Average --period 60 --threshold $UPPER_UTILIZATION_THRESHOLD --comparison-operator GreaterThanThreshold --evaluation-periods 10 --unit Percent --alarm-actions $scaleUpPolicyARN
mon-put-metric-alarm --alarm-name courseraUtilizationScaleDownAlarm --namespace "AWS/EC2" --metric-name CPUUtilization --dimensions "AutoScalingGroupName=courseraASG" --statistic Average --period 60 --threshold $LOWER_UTILIZATION_THRESHOLD --comparison-operator LessThanThreshold --evaluation-periods 20 --unit Percent --alarm-actions  $scaleDownPolicyARN
# Trigger 2 - Waiting Time
mon-put-metric-alarm --alarm-name courseraScaleUpAlarm --namespace coursera --metric-name WaitingTime --statistic Average --period 60 --threshold 100 --comparison-operator GreaterThanThreshold --evaluation-periods 1 --alarm-actions $scaleUpPolicyARN

# Backup - This metric should fire if the WaitingTime goes above a threshold.
mon-put-metric-alarm --alarm-name courseraBackupScaleUpAlarm --namespace coursera --metric-name WaitingTime --statistic Average --period 120 --threshold $UPPER_WAITING_TIME_THERSHOLD --comparison-operator GreaterThanThreshold --evaluation-periods 1 --alarm-actions $backupScaleUpPolicyARN
mon-put-metric-alarm --alarm-name courseraBackupScaleDownAlarm --namespace coursera --metric-name WaitingTime --statistic Average --period 120 --threshold $LOWER_WAITING_TIME_THERSHOLD --comparison-operator LessThanThreshold --evaluation-periods 1 --alarm-actions $backupScaleDownPolicyARN

