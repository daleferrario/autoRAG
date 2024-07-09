# Use the latest version of Alpine Linux as the base image
FROM alpine:latest

# Install curl and bind-tools without keeping a cache of the packages
RUN apk --no-cache add curl bind-tools

# Copy the update_namecheap_dns.sh script to the specified location in the container
COPY update_namecheap_dns.sh /usr/local/bin/update_namecheap_dns.sh

# Make the script executable
RUN chmod +x /usr/local/bin/update_namecheap_dns.sh

# Create a crontab file to run the script every 30 minutes
RUN echo "*/30 * * * * /usr/local/bin/update_namecheap_dns.sh" > /etc/crontabs/root

# Debugging step: Verify the script exists and is executable
RUN ls -l /usr/local/bin/update_namecheap_dns.sh

# Ensure the script runs once on container start and then start cron daemon in the foreground
ENTRYPOINT /usr/local/bin/update_namecheap_dns.sh && crond -f
