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
sudo docker run -it -v /home/ubuntu/data:/data --network host ajferrario/autorag:latest