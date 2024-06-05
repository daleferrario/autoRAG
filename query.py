from llama_index.llms.ollama import Ollama
from pathlib import Path
from llama_index.core import VectorStoreIndex, ServiceContext, SimpleDirectoryReader, StorageContext, Settings
from llama_index.vector_stores.chroma import ChromaVectorStore
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
import sys, datetime, logging, chromadb

print("STARTING")

if ((len(sys.argv) == 2) and (sys.argv[1] == "-v")):
    verbose=True
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        filename="dgm.log",
    )

logging.info("STARTING")

llm_model_used = "tinydolphin"
document_directory_used = "data/dgm_data"
embedding_model_used = "BAAI/bge-base-en-v1.5"
collection_name_used = "dgm_data"
chunk_size_used = 512
chunk_overlap_used = 20
personality_used = "Respond as an experienced manager who has had employees around the world, has delivered large projects, has worked with other managers and leaders, has seen lots of HR related issues and challenges, and has a good grasp of all management related disciplines"

# Set embeddings model
Settings.embed_model = HuggingFaceEmbedding(model_name=embedding_model_used)

# Load data
documents = SimpleDirectoryReader(document_directory_used).load_data()
documents_loaded=len(documents)
logging.info("DOCUMENTS LOADED: %d", documents_loaded)

# Create ChromaDB
chroma_client = chromadb.EphemeralClient()
chroma_collection = chroma_client.create_collection(collection_name_used)
vector_store = ChromaVectorStore(chroma_collection=chroma_collection)
storage_context = StorageContext.from_defaults(vector_store=vector_store)

logging.info("CHROMADB CREATED")

## Initialize Ollama and ServiceContext
Settings.llm = Ollama(model=llm_model_used, request_timeout=600.0)
Settings.chunk_size=chunk_size_used
Settings.chunk_overlap=chunk_overlap_used

logging.info("OLLAMA SERVICES INITIALIZED")

## Llama Index
index = VectorStoreIndex.from_documents(documents, storage_context=storage_context)
query_engine = index.as_query_engine()

logging.info("DOCUMENTS INDEXED")

prompt_input=""
while(prompt_input != "done"):
    prompt_input = input("Enter Prompt (quit to stop): ")

    #prompt_input = "What does Develop Great Managers say about about where Laura Ortman grew up?"


    if verbose:
        logging.info("RETRIEVING CHUNKS FOR %s", prompt_input)
        retriever = index.as_retriever()
        relevant_docs = retriever.retrieve(prompt_input)
        #for result in relevant_docs:
        #    document_id=result.document_id
        #    chunk_data=index.get_document(document_id)
        #    logging.info(chunk_data)
        logging.info("RELEVANT DOCS: %s", relevant_docs)
        logging.info(relevant_docs)

    ## Query
    logging.info("PROMPT: %s", prompt_input)
    #print(f"Prompt: {prompt_input}")
    response = query_engine.query(prompt_input)
    logging.info("%s", prompt_input)
    print(response)

logging.info("DONE")