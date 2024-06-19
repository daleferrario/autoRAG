##Workflow
- Install AWS CLI
- Collect data location for RAG app
- Run autoRAGSetup.py [TBD]
- Deploy autoRAG.yml as a CloudFormation template
- Capture the output URL
- Run desired RAG queries through query.py
- Teardown autoRAG.yml CloudFormation application


# DEMO
aws cloudformation create-stack --template-body file://infrastructure/autoRAG.yml --stack-name test1 --parameters --parameters ParameterKey=KeyPair,ParameterValue=autoRAG ParameterKey=InstanceType,ParameterValue=m7g.large  --region us-west-2
# wait a few mins
ollama ps
sudo docker ps
scp -i ~/.ssh/autoRAG.pem -r data ubuntu@ec2-35-94-102-162.us-west-2.compute.amazonaws.com:/home/ubuntu/ 
sudo docker run --rm -it -v /home/ubuntu/data:/data --network host ajferrario/autorag:latest

# Testing with different AWS instances
# m5.large - 1 vCPU, 16 GiB memory, no GPU
# t4g.xlarge - 4 vCPU, 16 GiB memory, no GPU
# p5.xlarge - 4  vCPU, 16 GiB? memory, 1 GPU (NVIDIA Tesla P100)
# DaleConsoleKeyPair
deploy -n <stack-name> -k <keypair> -i <ec2-instanct-type>

# Testing with different LLM models
# tinydolphin (default)
#
# jurassic-1 Jumbo - very large
# llama3b - large
# WuDao 2.0 Base - medium
# Llama2b - medium
# GPT-2 - small
docker run --rm -it -v ~/data:/data --network host --name autorag ajferrario/autorag:latest -l llm [-v -e <embedding_model> -c <chunk_size> -o <chunk_overlap> -p <personality_used> -q <query_type>]