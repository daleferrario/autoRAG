from llama_index.llms.ollama import Ollama
from pathlib import Path
import chromadb
from llama_index.core import VectorStoreIndex, ServiceContext, SimpleDirectoryReader, StorageContext
# from llama_index.storage.storage_context import StorageContext
from llama_index.vector_stores.chroma import ChromaVectorStore
from llama_index.embeddings.huggingface import HuggingFaceEmbedding

# from llama_index.core import VectorStoreIndex, SimpleDirectoryReader, Settings, ServiceContext
# from llama_index.embeddings.huggingface import HuggingFaceEmbedding
# from llama_index.llms.ollama import Ollama
# from llama_index.vector_stores.chroma import ChromaVectorStore
# from llama_index.storage.storage_context import StorageContext
# from llama_index import StorageContext
# import chromadb

print("Starting")

## Embeddings
# set embeddings model
embed_model = HuggingFaceEmbedding(model_name="BAAI/bge-base-en-v1.5")
# Load data
documents = SimpleDirectoryReader("data/mlg_data").load_data()

# Create ChromaDB
chroma_client = chromadb.EphemeralClient()
chroma_collection = chroma_client.create_collection("mlg_data")
vector_store = ChromaVectorStore(chroma_collection=chroma_collection)
storage_context = StorageContext.from_defaults(vector_store=vector_store)

## Initialize Ollama and ServiceContext
llm = Ollama(model="tinydolphin", request_timeout=600.0)
service_context = ServiceContext.from_defaults(llm=llm, embed_model=embed_model)

## Llama Index
index = VectorStoreIndex.from_documents(documents, storage_context=storage_context, service_context=service_context)
query_engine = index.as_query_engine()

## Query
print("RESPONSE")
response = query_engine.query("What does Develop Great Managers say about about where Laura Ortman grew up?")
print(response)

print("DONE")