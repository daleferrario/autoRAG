# Getting Started
First you need to decide if you're going to use a dev-server or run things locally. The dev server option is convenient if your local machine doesn't have a GPU or is low-powered and will struggle running a handful of containers.

## Dev Server
- Run the setup_project script to make sure you have AWS CLI installed and configured and feel free to skip the rest.
```
./setup_project.sh
```
- Deploy and use the dev server following the [Dev Server README](scripts/dev/README.md)
- Do the rest of the steps on your dev server

## Environment Setup
- Collect key files from the Distill Resources Google drive document and put them in some known location
  - bot.key for discord_bot
  - slack_app_token for slack_app
  - slack_bot_token for slack_app
- Run setup_project.sh and complete all steps
```
./setup_project.sh
```
## Run Distill-AI
You have a choice of environment files when you launch distill but the test script will pick a default one if you don't have an opinion

Simple version
```
./local_test.sh
```
Env file specified
```
./local_test.sh -e DGMtest.env
```
local_test.sh will clean-up the environment when you exit using ctrl-c, so just give it time to do that.

This will output logs for the customer-specific and shared services that you can follow. Logs will overwrite when you start the services again.
```
tail -f test/docker-compose-customer.log
tail -f test/docker-compose-shared.log
```
## Development flow
If you want to make any changes to the code of the services you'll need to rebuild before running again.
```
./make.sh
```

If you just change docker-compose files or environment variables a rebuild isn't needed.
## End of Day
Make sure to shut down your dev server at the end of the day to save cost. There is supposed to be a cron job that will do this automatically after 30 minutes of inactivity but that's not really working yet.
```
./scripts/dev/hibernate_dev_server.sh
```
## Deploy for customers
TBD


## Models and Instances
### Testing with different AWS instances
- m5.large - 1 vCPU, 16 GiB memory, no GPU
- t3.xlarge - 4 vCPU, 16 GiB memory, no GPU
- g4dn.xlarge - 4 vCPU, 16 GiB memory, 1 GPU (NVIDIA Tesla P100)
- c7.48xlarge - 192 vCPU, 384 GiB memory, no GPU

### Testing with different LLM models
- tinydolphin (default)
- jurassic-1 Jumbo - very large
- llama3b - large
- WuDao 2.0 Base - medium
- Llama2b - medium
- GPT-2 - small