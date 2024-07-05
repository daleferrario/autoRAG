# Dev Server
The purpose of the dev server scripts and infrastructure template are to allow remote development work on Distill to take place without direct interaction with AWS.

You'll need to have the AWS CLI installed and configured for these scripts to work.

State for the dev server will live in the state folder. You shouldn't need to mess with that.

## Deploy
The deploy script will deploy a cloudformation stack containing an EC2 VM and the associated objects needed for SSH access and development. The repo will be pre-cloned on your dev server.

Deployment is done in us-east-1 so please make sure to use a keypair from that region.

Simple Example
```
./scripts/dev/deploy_dev_server.sh -k <path_to_key_pair>
./scripts/dev/deploy_dev_server.sh -k <path_to_key_pair> -i t3a.2xlarge
```

GPU server model
```
./scripts/dev/deploy_dev_server.sh -k <path_to_key_pair> -i "g4dn.xlarge"
```

## Use
The use script serves 2 purposes:
1 - Restart the dev server if it's been hibernated
2 - Capture the dev server state and use that state to create configuration that will allow you to use remote SSH to connect VSCode to your dev server.
```
./scripts/dev/use_dev_server.sh
```

## Hibernate
The hibernate script shuts down your dev server to save on cost while not in use.
```
./scripts/dev/hibernate_dev_server.sh
```

## Teardown
The teardown script will delete the stack and all associated infrastructure. Be careful because you could nuke code changes which haven't been pushed to the repo.
```
./scripts/dev/teardown_dev_server.sh
```

## Start Docker Containers after Hibernate
After restarting server, these containers need to be restarted, and ollama needs to have the models loaded and running.
```
docker run -d -p 11434:11434 --gpus all --name [ollama_container_name] ollama/ollama
docker exec ollama [ollama_container_name] pull llama3
docker exec ollama [ollama_container_name] run llama3
```

```
export STORAGE_LOCATION=$HOME/anythingllm && \
mkdir -p $STORAGE_LOCATION && \
touch "$STORAGE_LOCATION/.env" && \
docker run -d -p 3001:3001 \
--gpus all \
--cap-add SYS_ADMIN \
-v ${STORAGE_LOCATION}:/app/server/storage \
-v ${STORAGE_LOCATION}/.env:/app/server/.env \
-e STORAGE_DIR="/app/server/storage" \
mintplexlabs/anythingllm
```