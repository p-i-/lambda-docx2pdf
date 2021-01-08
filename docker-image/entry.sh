#!/bin/sh

echo 'Fails for /home/app/ on remote, succeeds for /tmp/' > /home/app/output_and_error_file

exec python -m awslambdaric $1
