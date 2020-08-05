#!/bin/bash
set -o pipefail
elastalert-create-index --config config.yaml |& tee /tmp/ea.log
elastalert --debug --config config.yaml |& tee -a /tmp/ea.log
