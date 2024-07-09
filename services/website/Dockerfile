# Use the official NGINX image from Docker Hub
FROM nginx:latest

# Copy the NGINX configuration file
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the static website files
COPY html /usr/share/nginx/html

# Copy the start script
COPY start_nginx.sh /start_nginx.sh

# Make the start script executable
RUN chmod +x /start_nginx.sh

# Set the entrypoint to the start script
ENTRYPOINT ["/start_nginx.sh"]
