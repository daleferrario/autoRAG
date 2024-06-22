from google.oauth2 import service_account
from googleapiclient.discovery import build

# Path to your service account key file
SERVICE_ACCOUNT_FILE = 'distill-ai-key.json'

# Define the scopes required
SCOPES = ['https://www.googleapis.com/auth/drive']

# Authenticate using the service account
credentials = service_account.Credentials.from_service_account_file(
    SERVICE_ACCOUNT_FILE, scopes=SCOPES)

# Build the Drive API client
service = build('drive', 'v3', credentials=credentials)

folder_id = '1o3lbUzJxehxOeGUwk7vt-oILENRSe3H8'
# List the files in the Drive
query = f"'{folder_id}' in parents"
results = service.files().list(q=query, pageSize=10, fields="files(id, name)").execute()
items = results.get('files', [])

if not items:
    print('No files found.')
else:
    print('Files:')
    for item in items:
        print(f'{item["name"]} ({item["id"]})')
