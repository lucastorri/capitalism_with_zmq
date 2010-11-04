#!/bin/bash

./zmq_jobs.rb manager listen_everyone 1 &

./zmq_jobs.rb employee number1 1 &
./zmq_jobs.rb employee number2 1 &

./zmq_jobs.rb worker_manager listen_everyone 1 &

./zmq_jobs.rb poor_worker number1 3 &
./zmq_jobs.rb poor_worker number2 3 &