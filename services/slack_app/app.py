import json
import os
import logging
import asyncio
import aiohttp
from slack_bolt.async_app import AsyncApp
from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler

# Configure logging
logging.basicConfig(level=logging.INFO)

# Initialize a Bolt for Python app
app = AsyncApp(token=os.getenv("SLACK_BOT_TOKEN"))

@app.command("/distill")
async def handle_distill(ack, body, respond):
    await ack()
    user_id = body["user_id"]
    channel_id = body["channel_id"]
    text = body["text"]
    logging.info(f"body: {body}")
    response_message = await send_question_to_rest_server(body["team_id"], text)
    await respond(f"<@{user_id}> asked: {text}\nServer response: {response_message}")  # Acknowledge the command

async def send_question_to_rest_server(team_id: str, question: str) -> str:
    url = f"http://llama-index.{team_id}:{os.getenv('REST_SERVER_PORT')}/query"
    params = {'question': question}
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, params=params) as response:
                if response.status == 200:
                    resp = await response.text()
                    return json.loads(resp).get("message", "No message in response.")
                else:
                    logging.error(f"Failed to get response from server: {response.status}")
                    return "Failed to get response from server."
    except aiohttp.ClientError as e:
        logging.error(f"HTTP request failed: {e}")
        return "Failed to connect to the server."

async def main():
    # Initialize AsyncSocketModeHandler to use Slack's WebSocket mode
    handler = AsyncSocketModeHandler(app, os.getenv("SLACK_APP_TOKEN"))
    await handler.start_async()

if __name__ == "__main__":
    asyncio.run(main())
