from llama_index.core import VectorStoreIndex, StorageContext, Settings
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.readers.google import GoogleDriveReader
from llama_index.vector_stores.chroma import ChromaVectorStore
import chromadb
import os

# Environment Variables
collection_name = os.getenv("CUSTOMER_ID")
google_drive_folder_id = os.getenv("FOLDER_ID")
google_drive_service_account_key = os.getenv("SERVICE_ACCOUNT_KEY", None)

# Local Variables
chromadb_host = "chromadb"
chromadb_port = 8000
chunk_size = 1024
chunk_overlap = 20
embedding_model = "BAAI/bge-base-en-v1.5"
google_drive_service_account_key_path = "service_account_key.json"


# Embedding Settings
Settings.embed_model = HuggingFaceEmbedding(model_name=embedding_model)
Settings.chunk_size = chunk_size
Settings.chunk_overlap = chunk_overlap

# Collect documents
if google_drive_service_account_key:
  reader = GoogleDriveReader(service_account_key=google_drive_service_account_key)
else:
  reader= GoogleDriveReader(service_account_key_path=google_drive_service_account_key_path)
documents = reader.load_data(folder_id=google_drive_folder_id)

# Create Storage Context
chroma_client = chromadb.HttpClient(host=chromadb_host, port=chromadb_port)

if collection_name in chroma_client.list_collections():
  # TODO: Remove this hack and implement an id-based upsert
  chroma_client.delete_collection(collection_name)
  chroma_client.create_collection(collection_name)

chroma_collection = chroma_client.get_collection(collection_name)
vector_store=ChromaVectorStore(chroma_collection=chroma_collection)
storage_context = StorageContext.from_defaults(vector_store=vector_store)

# Create persisted index
index = VectorStoreIndex.from_documents(
    documents, storage_context=storage_context
)