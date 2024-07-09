FROM nginx:latest

RUN apt-get update && apt-get install -y gettext-base openssl

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start_nginx.sh /start_nginx.sh
COPY create_self_signed_cert.sh /create_self_signed_cert.sh

RUN chmod +x /start_nginx.sh /create_self_signed_cert.sh

ENTRYPOINT ["/start_nginx.sh"]
