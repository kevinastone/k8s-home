#!/bin/bash

kubectl exec --stdin --tty -n garage garage-0 -- ./garage $*
