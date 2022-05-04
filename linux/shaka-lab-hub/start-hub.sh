#!/bin/bash

cd /opt/shaka-lab/selenium-hub

java \
  -jar selenium-server-standalone-3.141.59.jar \
  -role hub \
  -port 4444 \
  -throwOnCapabilityNotPresent true \
  -maxSession 1 \
  -timeout 30 \
  -browserTimeout 120 \
  -cleanUpCycle 5000
