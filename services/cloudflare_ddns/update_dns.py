import os
import requests
import schedule
import time
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Cloudflare API credentials from environment variables
CF_API_TOKEN = os.getenv("CF_API_TOKEN")
CF_ZONE_ID = os.getenv("CF_ZONE_ID")
RECORD_NAMES = os.getenv("RECORD_NAMES").split(',')

# API URL templates
LIST_RECORDS_URL_TEMPLATE = "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records?type=A&name={record_name}"
UPDATE_RECORD_URL_TEMPLATE = "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}"

def get_current_ip():
    response = requests.get("https://1.1.1.1/cdn-cgi/trace")
    response_text = response.text
    for line in response_text.split("\n"):
        if line.startswith("ip="):
            return line.split("=")[1]
    return None

def get_record_id(record_name):
    headers = {
        "Authorization": f"Bearer {CF_API_TOKEN}",
        "Content-Type": "application/json"
    }
    list_records_url = LIST_RECORDS_URL_TEMPLATE.format(zone_id=CF_ZONE_ID, record_name=record_name)
    response = requests.get(list_records_url, headers=headers)
    if response.status_code == 200:
        data = response.json()
        if data["success"]:
            return data["result"][0]["id"]
    return None

def update_dns_record(record_id, current_ip, record_name):
    update_url = UPDATE_RECORD_URL_TEMPLATE.format(zone_id=CF_ZONE_ID, record_id=record_id)
    headers = {
        "Authorization": f"Bearer {CF_API_TOKEN}",
        "Content-Type": "application/json"
    }
    data = {
        "type": "A",
        "name": record_name,
        "content": current_ip,
        "ttl": 120,
        "proxied": True
    }
    response = requests.put(update_url, headers=headers, json=data)
    return response.status_code == 200 and response.json().get("success", False)

def job():
    current_ip = get_current_ip()
    if not current_ip:
        logging.error("Could not determine current IP address.")
        return

    for record_name in RECORD_NAMES:
        record_id = get_record_id(record_name)
        if not record_id:
            logging.error(f"Could not find DNS record ID for {record_name}.")
            continue

        headers = {
            "Authorization": f"Bearer {CF_API_TOKEN}",
            "Content-Type": "application/json"
        }
        list_records_url = LIST_RECORDS_URL_TEMPLATE.format(zone_id=CF_ZONE_ID, record_name=record_name)
        current_record_ip = requests.get(list_records_url, headers=headers).json()["result"][0]["content"]

        if current_ip != current_record_ip:
            if update_dns_record(record_id, current_ip, record_name):
                logging.info(f"IP updated to {current_ip} for {record_name}")
            else:
                logging.error(f"Failed to update IP for {record_name}")
        else:
            logging.info(f"IP address has not changed for {record_name}.")

# Schedule the job every 30 minutes
schedule.every(30).minutes.do(job)

# Run the job once at startup
job()

while True:
    schedule.run_pending()
    time.sleep(1)
