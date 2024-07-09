# Use the official NGINX image from Docker Hub
FROM nginx:latest

# Install envsubst
RUN apt-get update && apt-get install -y gettext-base

# Copy the NGINX configuration template and the start script
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start_nginx.sh /start_nginx.sh

# Make the start script executable
RUN chmod +x /start_nginx.sh

# Set the entrypoint to the start script
ENTRYPOINT ["/start_nginx.sh"]
