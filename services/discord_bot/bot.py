import discord
from discord.ext import commands
import logging
import os
import redis
import aiohttp

# Configure logging
logging.basicConfig(level=logging.INFO)

# Set up intents
intents = discord.Intents.default()

# Create bot instance
bot = commands.Bot(command_prefix='!', intents=intents)

# Create redis connection
r = redis.Redis(host='customer_db', port=6379, decode_responses=True)

@bot.event
async def on_ready():
    logging.info(f'Logged in as {bot.user}')
    try:
        synced = await bot.tree.sync()
        logging.info(f'Synced {len(synced)} commands')
    except Exception as e:
        logging.error(f'Failed to sync commands: {e}')

@bot.tree.command(name="distill-question", description="Submit a question for distillation")
async def distill_question(interaction: discord.Interaction, question: str):
    guild = interaction.guild  # Capture the guild where the command was invoked
    await interaction.response.defer()  # Defer the response to give more time
    if guild:
        guild_id = guild.id
        response = await send_question_to_anythingllm(guild_id, question)
        await interaction.followup.send(f"You asked in {guild.name}: {question}\nServer response: {response}")
    else:
        await interaction.followup.send(f"You asked: {question}\nLet me distill that for you...")

async def send_question_to_anythingllm(guild_id: int, question: str) -> str:
    customer_id = r.get(f"DISCORD_SERVER_ID:{guild_id}:CUSTOMER_ID")
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
    # TODO: remove the hack of treating a guild_id as a customer_id. In future there's probably a customerID lookup here based
    # on the guild ID.
    try:
        async with aiohttp.ClientSession() as session:
            # Create Manager User
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

# Run the bot
bot.run(os.getenv('DISCORD_BOT_KEY'))
