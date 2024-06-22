import discord
from discord.ext import commands

# Function to read the token from a file
def read_token():
    with open('bot.key', 'r') as file:
        return file.read().strip()

# Set up intents
intents = discord.Intents.default()
intents.message_content = True  # Ensure this is set to True if you need to read message content
intents.dm_messages = True  # Ensure the bot can handle DMs

# Create bot instance
bot = commands.Bot(command_prefix='!', intents=intents)

@bot.event
async def on_ready():
    print(f'Logged in as {bot.user}')

@bot.command()
async def hello(ctx):
    await ctx.send('Hello!')

# Event listener for all messages
@bot.event
async def on_message(message):
    # Check if the message is from the bot itself to avoid infinite loops
    if message.author == bot.user:
        return
    
    # Check if the message is a DM
    if isinstance(message.channel, discord.DMChannel):
        await message.channel.send('Hello! How can I help you?')
    else:
        await bot.process_commands(message)

# Read token from file
token = read_token()

# Run the bot
bot.run(token)
