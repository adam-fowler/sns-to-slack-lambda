# SNS to Slack

This is a Swift based AWS Lambda that will publish Simple Notification System (SNS) messages to a Slack channel.

## Setup Slack incoming webhook

Click [here](https://api.slack.com/apps) to go to the Slack Apps setup page. Click on "Create New App". Provide a name for your app and choose the workspace you want to post to. Click on "Incoming Webhooks". Click the switch to activate incoming webhooks. Click on "Add new webhook". Choose a channel to post to and click "Allow". You now have a webhook URL. You can go to do the bottom of the "Incoming Webhooks" page and copy the URL.

## Build and install

Before continuing you will need [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/install/) installed. You will also need the AWS command line interface and AWS SAM installed. You can install `awscli` and `sam` with Homebrew.
```
brew tap aws/tap
brew install awscli
brew install aws-sam-cli
```
There are two stages to getting the Lambda installed.

The install process can be broken into two stages, each with its own shell script.
1) build-and-package.sh: Building and packaging the lambda. This uses the `archive` command plugin that comes with the swift-aws-lambda-runtime
2) deploy.sh: Deploying the packaged Lambda to AWS using AWS SAM. The first time you run this you should add the command line parameter `--guided`. This will ask a number of questions about how you want the deployment to work.

## Link to Slack

The Lambda uses the Environment variable SLACK_HOOK_URL to get the URL to post to. You need to edit the SAM `deploy.yml`` to point this environment variable to the correct URL.

