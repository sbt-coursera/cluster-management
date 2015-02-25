# Overview

This is the repository for managing the cluster infrastructure for the sbt-coursera plugin. We use *EC2* instances to run many instances of the grading scripts in parallel.

* Every EC2 worker machine starts grading automatically after booting (multiple instances of the script on each machine). This machine can be started by starting from the latest version of the coursera-worker image. To find it just search for coursera-worker in the community AMIs in AWS. 
* A Master node reads the queue length and computes an estimated time for an new submission to get graded. This data is published every minute to a *CloudWatch metric*. Master can be found by searching for `coursera-master` in the AWS (use the latest version).
* We use an *AutoScaling group* to scale up or down the EC2 instances based on the estimated waiting time. The script `as-start-master.sh` will create an immortal master, while `as-start-workers.sh` will create the scaling groups. 
* Log files are stored in a *S3 bucket*. This bucket is mounted on startup on all workers. We also store some files with settings on S3 so that the worker configuration can be easily changed.
* We use a *SNS topic* to publish error notifications, from where the messages get published to the `progfun-coursera-logs@googlegroups.com` group.


## EC2 Instances

We have one master instance and a variable number of slaves. The [EC2 dashboard](https://console.aws.amazon.com/ec2/home?region=us-east-1#s=Instances) lists all running instances.

To login to one of the instances, copy its public URL (e.g. `ec2-23-23-27-59.compute-1.amazonaws.com`) and use the following SSH command

    ssh -i /path/to/coursera.pem ubuntu@ec2-23-23-27-59.compute-1.amazonaws.com

### Updating Instances

There are several scenarios for updating the scripts on an instance:

1. Changes to the grading script: All workers need to be re-started (changes from github are pulled on startup). This can be easily achieved by incrementing the value in the `settings/rebootGeneration` file (see S3 section below). If the content of that file changes, all workers will restart.
2. Changes to the settings file in `settings/` on the S3 bucket: again, just re-starting the workers should be enough. Sometimes this is not even necessary.
3. Actual changes to the files of the instance are required (e.g. changing the cron job). Then a new AMI image is required, see below.


### AMI Images

There are two AMI images for coursera (master and worker). In order to make changes to an image, you need to login to a machine running that image, make the changes, and then right-click on the EC2 instance and select *Create Image (EBS AMI)*.

Choose a consecutive name for the image (`coursera-worker-0.3`, `coursera-master-0.4`, ...)

**Careful**: when updating the worker image, the AutoScaling group has to be re-created with the new image ID - otherwise it will continue to create instances from the old image (see below).

### Startup Script

The `startMaster` / `startWorker` scripts are executed on startup using an upstart script (`/etc/init/coursera.conf`).

In both cases, the `progfun-scripts` git repository is updated first. This way the scripts can be changed without creating a new AMI image, a reboot is sufficient.

The startup script mounts the coursera S3 bucket on `$GRADING_HOME/s3data`.


### Cron Scripts

Both the server and the workers have a cron job (run `crontab -e` to edit): the server for updating the CloudWatch measure, the workers to check if the grading script is making progress (reboot otherwise).


## AutoScaling Group

**Main idea**: The goal is to use the spot instances when they are available. Since they are cheap the spot-instances are kept slightly underutilized which results in small latency. If the spot-instances are not available we try to grade every submission within (more or less) 5 minutes. For that, the we estimate the time it takes for a submission to get through the queue (see script `update-metric`) by

                   (queueLength * estimatedGradingTime)
    WaitingTime = --------------------------------------
                  (numberOfMachines * workersPerMachine)

There are two scaling rules: scale up 1 machines if WaitingTime > 300s, scale down 1 machine if waiting time < 50s.

The scripts for managing the clster are:
 * `as-base.sh` is sourced to all other scripts and contains all the configuration parameters. All of the params that I usually use for tweaking are now there. If you need to add something feel free to change it in the other scripts. This could also be loaded from a file, but i do not have time to do this currently. If you need some of these params to be moved to the config in s3 please fire an issue or submit a pull request. 
 * `as-kill-workers.sh` delete all the auto-scaling groups and all the instances in them. When you do this make sure that you have an instance outside the scaling group running that can still grade the incoming tasks.
 * `as-start-workers.sh` starts the cluster workers by creating the spot instance and backup scaling groups.
 * `as-start-master.sh` starts a scaling group for master. This is usually done only once in the beginning.
 * `as-kill-master.sh` kills the scaling groups for the master. This is usually done only once in the end.
 * `as-restart-workers.sh` kills all the worker groups (together with instances) and starts the new ones according to the config.

**Choosing Instances**: Always try to choose instances with the fastest cores. This will improve user experience by reducing the waiting time. You can calculate the speed of a core by dividing the number of EC2 compute units with the number of phisical cores. When changing the instance type make sure that the number of graders per machine is equal to `number_of_cores + 1`

### Updating the Worker AMI Image

The AMI image which is used when the AutoScaling group starts new workers cannot be updated. Instaead, a new image has to be created, and the group has to be deleted and re-created. Deleting a group will also shutdown all running instances.

Refer to the `as-commands.txt` text file.


## CloudWatch Measure: WaitingTime

The master node updates a [CloudWatch measure named WaitingTime](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#c=CloudWatch&s=Metrics&graph=!CA0!ST1!ET2!NS0!MN3!SS4!PD5!AX6!VAcoursera~-PT3H~-PT0H~WaitingTime~Average~60~Left) every minute (cron job that runs the script `update-metric`, type `crontab -e` to edit).

This metric is used by AutoScale to scale up or down the worker instances.


## S3 Bucket Layout

As mentioned before, the S3 bucket is mounted on the master and every worker using `s3fs` under `$GRADING_HOME/s3data`.

Note that S3 does not have the concept of directories built-in, so s3fs uses some kind of encoding to emulate directories. When using other clients to write data to the bukcet, s3fs might get confused (I tried `Transmit` on OS X, then there are problems with wrong file permissions, new directories not visible in s3fs, ...). The [S3 web interface](https://console.aws.amazon.com/s3/home) shows a file and a folder for every s3fs directory.

Also note that S3 is eventually consistent.

### Directory Structure
Each organization can have multiple clusters running and the name of the cluster is stored in the file `$GRADING_HOME/clusterName`. All other paths are relative to the cluster name in the `s3data`, i.e., ``s3Dir=$GRADING_HOME/s3data/`cat clusterName```. Relative to the `s3dir` the folder structure is the following:

* `logs` contains log files for individual workers: one log file for every graded submission, a log file of the alive-checker cron job, and a log file of the startup script.
* The logs of the master are not copied to S3 - log in to the master using SSH and check the `~/log` directory.
* `workerStates`: for each worker machine, a file for every process that is updated on each iteration of the grading script. This is used to check if the worker is still alive.
* `settings` contains settings (one per file) that are read by the scripts.
  * `rebootGeneration`: increasing the value in this file will make all workers reboot.
  * `workersPerMachine`: number of instances of the grading script on each worker machine.
  * `gradingTimeEstimate`: estimated time to grade one submission, used by the master to compute the WaitingTime measure (see above)
  * `debuggingEnabled`: if not workers will provide detailed logs of the grading process.
  * `masterImage`: image id of the master (AWS image). If you change the image the master scaling group needs a restart (`as-restart-master.sh`).
  * `workerImage`: image id of workers (AWS image). If you change the image the worker scaling groups needs a restart (`as-restart-workers.sh`).
  * `masterType`: type of the AWS instance to use for master (e.g., t1.micro). If you change the image the master scaling group needs a restart (`as-restart-master.sh`).
  * `workerType`: type of the AWS instance to use for workers in the main scaling group (e.g., c3.large). If you change the image the worker scaling groups needs a restart (`as-restart-workers.sh`).
  * `workerType2`: type of the backup worker. Should be different than `workerType`. Used for a backup scaling group. If you change the image the worker scaling groups needs a restart (`as-restart-workers.sh`).
* `courses` contains a folder for each course that the cluster is grading. For example (`parprog` and `progfun`). Furthermore, each course folder contains a file:
    * `apiKey`: required to access coursera API. **Careful**: this setting needs to be changed in multiple locations, see scripts in `heathermiller/progfun`.
    * `courseId`, `queueName` of the coursera class. Again, changes in the progfun repository are required.
    * `gitUrl` the url pointing to the repo. The username and password can be stored in the URL. 
    * `gitBranch` the branch used for deployment.
