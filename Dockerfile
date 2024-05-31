FROM ubuntu:22.04 as base

WORKDIR /app
COPY ./start.sh .
CMD ["sh" ,"start.sh"]

EXPOSE 11434
