import discord
from discord.ext import commands

# Function to read the token from a file
def read_token():
    with open('bot.key', 'r') as file:
        return file.read().strip()

# Set up intents
intents = discord.Intents.default()
intents.message_content = True

# Create bot instance
bot = commands.Bot(command_prefix='!', intents=intents)

@bot.event
async def on_ready():
    print(f'Logged in as {bot.user}')

@bot.command()
async def hello(ctx):
    await ctx.send('Hello!')

# Read token from file
token = read_token()

# Run the bot
bot.run(token)
