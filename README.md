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
# t3.xlarge - 4 vCPU, 16 GiB memory, no GPU
# g4dn.xlarge - 4 vCPU, 16 GiB memory, 1 GPU (NVIDIA Tesla P100)
# c7.48xlarge - 192 vCPU, 384 GiB memory, no GPU
infrastructure/scripts/deploy.sh -n <stack-name> -k ~/.ssh/DaleConsoleKeyPairWest1.pem -i <ec2-instanct-type> -r us-west-1

infrastructure/scripts/load_data.sh -d ~/autoRAG/data 

# Testing with different LLM models
# tinydolphin (default)
#
# jurassic-1 Jumbo - very large
# llama3b - large
# WuDao 2.0 Base - medium
# Llama2b - medium
# GPT-2 - small
infrastructure/scripts/run.sh -l <llm> [-v -e <embedding_model> -c <chunk_size> -o <chunk_overlap> -p <personality_used> -q <query_type>]

# Usage: PROGRAM -f <google_drive_folder_id> [-v --local -e <embedding_model> -c <chunk_size> -o <chunk_overlap> -p <personality_used> -t <query_type> -l <llm>]
# All arguments are optional
# -v is included to turn on logging at the INFO level, saving to a log file
# -e <embedding_model> is a model from HuggingFace, default is "BAAI/bge-base-en-v1.5"
# -c <chunk_size> is a number, default is 1024 (tokens)
# -o <chunk_overlap> is a number, default is 20 (tokens)
# -p <personality_used> is a sentence or paragraph, default is an experienced manager
# -q <query_type> is an incomplete sentence:), default is "answer the query", another good option is "comment on a post"
# -l <llm> is a large learning model, default is tinydolphin
# -f", "--google_drive_folder_id",required=True, type=str, help="The ID of the folder to use as the source for the files we need to embed and use for context.

<!-- def parse_args():
  """Parses arguments from the command line."""
  parser = argparse.ArgumentParser(description="Program description")
  parser.add_argument("-v", "--verbose", action="store_true", help="Turn on INFO level logging")
  parser.add_argument("-e", "--embedding_model", type=str, default="BAAI/bge-base-en-v1.5", help="Embedding model from HuggingFace")
  parser.add_argument("-c", "--chunk_size", type=int, default=1024, help="Chunk size in tokens")
  parser.add_argument("-o", "--chunk_overlap", type=int, default=20, help="Chunk overlap in tokens")
  parser.add_argument("-p", "--personality_used", type=str, default="an experienced manager who has had employees around the world, has delivered large projects, has worked with other managers and leaders, has seen lots of HR related issues and challenges, and has a good grasp of all management related disciplines", help="Personality used")
  parser.add_argument("-t", "--query_type", type=str, default="answer the query", help="Query type")
  parser.add_argument("-l", "--llm", type=str, default="tinydolphin", help="Large language model")
  parser.add_argument("-f", "--google_drive_folder_id",required=True, type=str, help="The ID of the folder to use as the source for the files we need to embed and use for context.")
  return parser.parse_args() -->
