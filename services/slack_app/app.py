import json
import os
import logging
import redis
import asyncio
import aiohttp
from slack_bolt.async_app import AsyncApp
from slack_bolt.adapter.socket_mode.async_handler import AsyncSocketModeHandler

# Configure logging
logging.basicConfig(level=logging.INFO)

# Initialize a Bolt for Python app
app = AsyncApp(token=os.getenv("SLACK_BOT_TOKEN"))

# Create redis connection
r = redis.Redis(host='customer_db', port=6379, decode_responses=True)

@app.command("/distill")
async def handle_distill(ack, body, respond):
    await ack()
    user_id = body["user_id"]
    channel_id = body["channel_id"]
    text = body["text"]
    logging.info(f"body: {body}")
    response_message = await send_question_to_anythingllm(body["team_id"], text)
    await respond(f"<@{user_id}> asked: {text}\nServer response: {response_message}")  # Acknowledge the command

async def send_question_to_anythingllm(team_id: str, question: str) -> str:
    customer_id = r.get(f"SLACK_WORKSPACE_ID:{team_id}:CUSTOMER_ID")
    api_key = r.get(f"CUSTOMER_ID:{customer_id}:API_KEY")
    url = f"http://anythingllm.{customer_id}:3001/api/v1"
    headers = {
        'accept': 'application/json',
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json'
    }

    query_payload = {
    "message": question,
    "mode": "query"
    }
    try:
        async with aiohttp.ClientSession() as session:
            async with session.post(url + f"/workspace/{customer_id}/chat", headers=headers, json=query_payload, ssl=False) as response:
                if response.status == 200:
                    resp = await response.json()
                    logging.info("query response received")
                    logging.info(f"{resp}")
                    return resp["textResponse"]
                else:
                    logging.error()
                    logging.error(f"Failed to get query response: {response}")
                    return "Sorry! We encountered an error trying to respond to your query."
    except aiohttp.ClientError as e:
        logging.error(f"HTTP request failed: {e}")
        return "Failed to connect to the server."

async def main():
    # Initialize AsyncSocketModeHandler to use Slack's WebSocket mode
    handler = AsyncSocketModeHandler(app, os.getenv("SLACK_APP_TOKEN"))
    await handler.start_async()

if __name__ == "__main__":
    asyncio.run(main())
