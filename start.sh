#!/bin/bash

#./zmq_jobs.rb manager listen_everyone 1 &

#./zmq_jobs.rb employee zmq1 1 &
#./zmq_jobs.rb employee zmq2 1 &

./zmq_jobs.rb worker_manager listen1 1 &

./zmq_jobs.rb poor_worker number1 3 &
./zmq_jobs.rb poor_worker number1 3 &