#!/bin/bash -x

source `dirname $0`/as-base.sh

# Auto scaling group for the master: require one running instance, ressurect it if it dies.
as-create-launch-config $MASTER_LC --image-id $MASTER_IMAGE --instance-type $MASTER_TYPE --key coursera

as-create-auto-scaling-group $MASTER_ASG --launch-configuration $MASTER_LC --availability-zones $ZONES --min-size 1 --max-size 1 --default-cooldown 60
