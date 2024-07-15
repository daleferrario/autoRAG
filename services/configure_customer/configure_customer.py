import asyncio
import aiohttp
import redis
import logging
import os

CUSTOMER_ID = os.getenv("CUSTOMER_ID")
API_KEY = os.getenv("API_KEY")
MANAGER_ACCOUNT_USERNAME = os.getenv("MANAGER_ACCOUNT_USERNAME")
ADMIN_ACCOUNT_PASSWORD= os.getenv("ADMIN_ACCOUNT_PASSWORD")

DISCORD_SERVER_IDS_TEXT = os.getenv("DISCORD_SERVER_IDS", "")
DISCORD_SERVER_IDS = [] if DISCORD_SERVER_IDS_TEXT == "" else DISCORD_SERVER_IDS_TEXT.split(",")

SLACK_WORKSPACE_IDS_TEXT = os.getenv("SLACK_WORKSPACE_IDS", "")
SLACK_WORKSPACE_IDS = [] if SLACK_WORKSPACE_IDS_TEXT == "" else SLACK_WORKSPACE_IDS_TEXT.split(",")

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

def add_customer_to_db():
    r = redis.Redis(host="customer_db")
    r.set(f"CUSTOMER_ID:{CUSTOMER_ID}:API_KEY", API_KEY)
    r.set(f"CUSTOMER_ID:{CUSTOMER_ID}:ADMIN_ACCOUNT_PASSWORD", ADMIN_ACCOUNT_PASSWORD)
    r.set(f"CUSTOMER_ID:{CUSTOMER_ID}:DISCORD_SERVER_IDS", DISCORD_SERVER_IDS_TEXT)
    r.set(f"CUSTOMER_ID:{CUSTOMER_ID}:SLACK_WORKSPACE_IDS", SLACK_WORKSPACE_IDS_TEXT)
    for id in DISCORD_SERVER_IDS:
        r.set(f"DISCORD_SERVER_ID:{id}:CUSTOMER_ID", CUSTOMER_ID)
    for id in SLACK_WORKSPACE_IDS:
        r.set(f"SLACK_WORKSPACE_ID:{id}:CUSTOMER_ID", CUSTOMER_ID)

async def configure_anythingllm():
    base_url = f"http://anythingllm.{CUSTOMER_ID}:3001/api/v1"
    headers = {
        'accept': 'application/json',
        'Authorization': f'Bearer {API_KEY}',
        'Content-Type': 'application/json'
    }

    user_payload = {
    "username": MANAGER_ACCOUNT_USERNAME,
    "password": "CHANGEME01",
    "role": "manager"
    }
    workspace_payload = {
    "name": f"{CUSTOMER_ID}"
    }
    manager_user=None
    default_workspace=None
    try:
        async with aiohttp.ClientSession() as session:
            # Create Manager User
            async with session.post(base_url + "/admin/users/new", headers=headers, json=user_payload, ssl=False) as response:
                if response.status == 200:
                    resp = await response.json()
                    logging.info("create user response received")
                    logging.info(f"{resp}")
                    manager_user=resp["user"]
                else:
                    logging.error()
                    logging.error(f"Failed to create user: {response.status}")

            # Create default workspace
            async with session.post(base_url + "/workspace/new", headers=headers, json=workspace_payload, ssl=False) as response:
                if response.status == 200:
                    resp = await response.json()
                    logging.info("workspace response received")
                    logging.info(f"{resp}")
                    default_workspace=resp["workspace"]
                     # Add manager user to default workspace
                    add_user_payload={
                        "userIds": [
                            manager_user["id"]
                        ]
                    }
                else:
                    logging.error(response)
                    logging.error(f"Failed to create workspace: {response.status}")

            async with session.post(base_url + f"/admin/workspaces/{default_workspace['id']}/update-users", headers=headers, json=add_user_payload, ssl=False) as response:
                if response.status == 200:
                    resp = await response.json()
                    logging.info("workspace users updated")
                    logging.info(f"{resp}")
                else:
                    logging.error(response)
                    logging.error(f"Failed to create workspace: {response.status}")
    except aiohttp.ClientError as e:
        logging.error(f"HTTP request failed: {e}")
        return "Failed to connect to the server."

async def configure():
    add_customer_to_db()
    await configure_anythingllm()
# Run the create_user function
if __name__ == "__main__":
    asyncio.run(configure())