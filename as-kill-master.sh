#!/bin/bash -x

source `dirname $0`/as-base.sh

# With --force-delete the group is also deleted when there are running instances. Those are terminated.
as-delete-auto-scaling-group $MASTER_ASG --force-delete

# policies are deleted together with the auto-scaling group
# alarms are deleted together with the auto-scaling group
as-delete-launch-config $MASTER_LC
