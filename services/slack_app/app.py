import os
import logging
import asyncio
from slack_bolt.async_app import AsyncApp
from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler

# Configure logging
logging.basicConfig(level=logging.INFO)

# Initialize a Bolt for Python app
app = AsyncApp(token=os.getenv("SLACK_BOT_TOKEN"))

@app.command("/distill")
async def handle_distill(ack, body, client):
    await ack()  # Acknowledge the command
    user_id = body["user_id"]
    channel_id = body["channel_id"]
    text = body["text"]
    
    response_message = "This is a sample response"
    await client.chat_postMessage(channel=channel_id, text=f"<@{user_id}> asked: {text}\nServer response: {response_message}")

async def main():
    # Initialize AsyncSocketModeHandler to use Slack's WebSocket mode
    handler = AsyncSocketModeHandler(app, os.getenv("SLACK_APP_TOKEN"))
    await handler.start_async()

if __name__ == "__main__":
    asyncio.run(main())
