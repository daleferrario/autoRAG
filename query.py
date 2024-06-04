from llama_index.llms.ollama import Ollama
from pathlib import Path
import chromadb
from llama_index.core import VectorStoreIndex, ServiceContext, SimpleDirectoryReader, StorageContext, Settings
from llama_index.vector_stores.chroma import ChromaVectorStore
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
import sys, datetime

if ((len(sys.argv) == 2) and (sys.argv[1] == "-v")):
    verbose = True
    print(f"STARTING VERBOSE {datetime.datetime.now().strftime("%c")}")
else:
    verbose=False

llm_model_used = "tinydolphin"
document_directory_used = "data/mlg_data"
embedding_model_used = "BAAI/bge-base-en-v1.5"
collection_name_used = "mlg_data"

# Set embeddings model
Settings.embed_model = HuggingFaceEmbedding(model_name=embedding_model_used)

# Load data
documents = SimpleDirectoryReader(document_directory_used).load_data()
if verbose:
    print(f"DOCUMENTS LOADED: {len(documents)} {datetime.datetime.now().strftime("%c")}")

# Create ChromaDB
chroma_client = chromadb.EphemeralClient()
chroma_collection = chroma_client.create_collection(collection_name_used)
vector_store = ChromaVectorStore(chroma_collection=chroma_collection)
storage_context = StorageContext.from_defaults(vector_store=vector_store)

if verbose:
    print(f"CHROMADB CREATED {datetime.datetime.now().strftime("%c")}")

## Initialize Ollama and ServiceContext
Settings.llm = Ollama(model=llm_model_used, request_timeout=600.0)
# service_context = ServiceContext.from_defaults(llm=Settings.llm, embed_model=Settings.embed_model)

if verbose:
    print(f"OLLAMA {Settings.llm} STARTED {datetime.datetime.now().strftime("%c")}")

## Llama Index
# index = VectorStoreIndex.from_documents(documents, storage_context=storage_context, service_context=service_context)
index = VectorStoreIndex.from_documents(documents, storage_context=storage_context)
query_engine = index.as_query_engine()

if verbose:
    print(f"DOCUMENTS INDEXED {datetime.datetime.now().strftime("%c")}")

question = "What does Develop Great Managers say about about where Laura Ortman grew up?"


if verbose:
    print(f"RETRIEVING CHUNKS FOR: {question} {datetime.datetime.now().strftime("%c")}")
    retriever = index.as_retriever()
    relevant_docs = retriever.retrieve(question)
    print(relevant_docs)

## Query
if verbose:
    print(f"PASSING {question} TO {llm_model_used} {datetime.datetime.now().strftime("%c")}")
else:
    print(f"Question: {question}")
response = query_engine.query(question)
print(response)

question = "What does Develop Great Managers say how managers find work life balance?"

if verbose:
    print(f"RETRIEVING CHUNKS FOR: {question} {datetime.datetime.now().strftime("%c")}")
    retriever = index.as_retriever()
    relevant_docs = retriever.retrieve(question)
    print(relevant_docs)

## Query
if verbose:
    print(f"PASSING {question} TO {llm_model_used} {datetime.datetime.now().strftime("%c")}")
else:
    print(f"Question: {question}")
response = query_engine.query(question)
print(response)

if verbose:
    print(f"DONE {datetime.datetime.now().strftime("%c")}")