#!/bin/bash

# This script ensures logs are uploaded to S3 before instance shutdown
# Place this in /etc/rc0.d/ to run during shutdown

# Run the upload script
/home/ubuntu/upload_logs.sh

# Wait for upload to complete
sleep 30

# Exit with success
exit 0