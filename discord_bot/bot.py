import discord
from discord.ext import commands
import logging
import os
import aiohttp

# Configure logging
logging.basicConfig(level=logging.INFO)

# Function to read the token from a file
def read_token():
    try:
        with open('bot.key', 'r') as file:
            return file.read().strip()
    except FileNotFoundError:
        logging.error("Token file not found. Please ensure 'bot.key' exists.")
        raise
    except Exception as e:
        logging.error(f"An error occurred while reading the token: {e}")
        raise

# Set up intents
intents = discord.Intents.default()

# Create bot instance
bot = commands.Bot(command_prefix='!', intents=intents)

# Read REST server host and port from environment variables
REST_SERVER_PORT = os.getenv('REST_SERVER_PORT', '8000')

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
        response = await send_question_to_rest_server(guild_id, question)
        await interaction.followup.send(f"You asked in {guild.name}: {question}\nServer response: {response}")
    else:
        await interaction.followup.send(f"You asked: {question}\nLet me distill that for you...")

async def send_question_to_rest_server(guild_id: int, question: str) -> str:
    url = f"http://llama-index.{guild_id}:{REST_SERVER_PORT}/query"
    params = {'question': question}
    # TODO: remove the hack of treating a guild_id as a customer_id. In future there's probably a customerID lookup here based
    # on the guild ID.
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, params=params) as response:
                if response.status == 200:
                    return await response.text()
                else:
                    logging.error(f"Failed to get response from server: {response.status}")
                    return "Failed to get response from server."
    except aiohttp.ClientError as e:
        logging.error(f"HTTP request failed: {e}")
        return "Failed to connect to the server."

# Read token from file
token = read_token()

# Run the bot
bot.run(token)
