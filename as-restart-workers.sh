#! /bin/bash

`dirname $0`/as-kill-workers.sh
sleep 120
`dirname $0`/as-start-workers.sh
