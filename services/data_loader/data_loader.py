from llama_index.core import VectorStoreIndex, StorageContext, Settings
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.readers.google import GoogleDriveReader
from llama_index.vector_stores.chroma import ChromaVectorStore
import chromadb
import json
import logging
import os

# Configure Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Environment Variables
collection_name = os.getenv("CUSTOMER_ID")
google_drive_folder_id = os.getenv("FOLDER_ID")
google_drive_service_account_key = json.loads(os.getenv("SERVICE_ACCOUNT_KEY"))

# Log environment variables
logger.info(f"Collection Name: {collection_name}")
logger.info(f"Google Drive Folder ID: {google_drive_folder_id}")

# Local Variables
chromadb_host = "chromadb"
chromadb_port = 8000
chunk_size = 1024
chunk_overlap = 20
embedding_model_name = "BAAI/bge-base-en-v1.5"

# Create Embedding Model
Settings.embed_model = HuggingFaceEmbedding(model_name=embedding_model_name)
logger.info("Embedding model created with HuggingFace model: %s", embedding_model_name)

# Collect documents
reader = GoogleDriveReader(service_account_key=google_drive_service_account_key)
logger.info("Using service account key from environment variable.")

documents = reader.load_data(folder_id=google_drive_folder_id)
logger.info(f"Loaded {len(documents)} documents from Google Drive folder: {google_drive_folder_id}")

# Create Storage Context
chroma_client = chromadb.HttpClient(host=chromadb_host, port=chromadb_port)
logger.info("Connected to ChromaDB at %s:%d", chromadb_host, chromadb_port)

try:
    chroma_collection = chroma_client.get_collection(name=collection_name)
    chroma_client.delete_collection(name=collection_name)
    logger.info("Existing collection '%s' deleted.", collection_name)
except Exception as e:
    logger.warning("Collection '%s' does not exist or could not be deleted: %s", collection_name, e)
    chroma_collection = chroma_client.create_collection(collection_name)
    logger.info("New collection '%s' created.", collection_name)

vector_store = ChromaVectorStore(chroma_collection=chroma_collection)
storage_context = StorageContext.from_defaults(vector_store=vector_store)
logger.info("Storage context created with Chroma Vector Store.")

# Create persisted index
VectorStoreIndex.from_documents(
    documents,
    storage_context=storage_context,
    chunk_overlap=chunk_overlap,
    chunk_size=chunk_size
)
logger.info("VectorStoreIndex created and persisted with chunk_size=%d and chunk_overlap=%d", chunk_size, chunk_overlap)
