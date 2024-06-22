from llama_index.llms.ollama import Ollama
from llama_index.core import VectorStoreIndex, StorageContext, Settings, PromptTemplate
from llama_index.readers.google import GoogleDriveReader
from llama_index.vector_stores.chroma import ChromaVectorStore
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
import logging, warnings, chromadb, os, argparse, ollama
import json

# Usage: PROGRAM -f <google_drive_folder_id> [-v --local -e <embedding_model> -c <chunk_size> -o <chunk_overlap> -p <personality_used> -t <query_type> -l <llm>]
# All arguments are optional
# -v is included to turn on logging at the INFO level, saving to a log file
# -e <embedding_model> is a model from HuggingFace, default is "BAAI/bge-base-en-v1.5"
# -c <chunk_size> is a number, default is 1024 (tokens)
# -o <chunk_overlap> is a number, default is 20 (tokens)
# -p <personality_used> is a sentence or paragraph, default is an experienced manager
# -q <query_type> is an incomplete sentence:), default is "answer the query", another good option is "comment on a post"
# -l <llm> is a large learning model, default is tinydolphin
# -f", "--google_drive_folder_id",required=True, type=str, help="The ID of the folder to use as the source for the files we need to embed and use for context.

def parse_args():
  """Parses arguments from the command line."""
  parser = argparse.ArgumentParser(description="Program description")
  parser.add_argument("-v", "--verbose", action="store_true", help="Turn on INFO level logging")
  parser.add_argument("-e", "--embedding_model", type=str, default="BAAI/bge-base-en-v1.5", help="Embedding model from HuggingFace")
  parser.add_argument("-c", "--chunk_size", type=int, default=1024, help="Chunk size in tokens")
  parser.add_argument("-o", "--chunk_overlap", type=int, default=20, help="Chunk overlap in tokens")
  parser.add_argument("-p", "--personality_used", type=str, default="an experienced manager who has had employees around the world, has delivered large projects, has worked with other managers and leaders, has seen lots of HR related issues and challenges, and has a good grasp of all management related disciplines", help="Personality used")
  parser.add_argument("-t", "--query_type", type=str, default="answer the query", help="Query type")
  parser.add_argument("-l", "--llm", type=str, default="tinydolphin", help="Large language model")
  parser.add_argument("-f", "--google_drive_folder_id",required=True, type=str, help="The ID of the folder to use as the source for the files we need to embed and use for context.")
  return parser.parse_args()

args = parse_args()

print("STARTING")

# If -v then turn on logging at INFO level, log to a file
if args.verbose:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        filename="log/dgm.log",
    )
logging.info('Arguments: {args}')

def warning_to_log(message, category, filename, lineno, file=None, line=None):
    log = logging.getLogger('py.warnings')
    log.warning('%s:%s: %s:%s', filename, lineno, category.__name__, message)

# Redirect warnings to the logging module
warnings.showwarning = warning_to_log

# Variables
collection_name_used = "data"
google_drive_service_account_key_path="service_account_key.json"
ollama_request_timeout=600.0
chromadb_port = 8000

logging.info("STARTING")

# Load the LLM model that will be used
ollama.pull(args.llm)

# Llama Index settings
Settings.embed_model = HuggingFaceEmbedding(model_name=args.embedding_model)
Settings.llm = Ollama(model=args.llm, request_timeout=ollama_request_timeout)
Settings.chunk_size=args.chunk_size
Settings.chunk_overlap=args.chunk_overlap

# Load data
documents = GoogleDriveReader(service_account_key_path=google_drive_service_account_key_path).load_data(folder_id=args.google_drive_folder_id)
documents_loaded=len(documents)
logging.info("DOCUMENTS LOADED: %d", documents_loaded)

# Connect to ChromaDB
chroma_client = chromadb.HttpClient(host=os.getenv('HOST', 'localhost'), port=chromadb_port)
chroma_collection = None
try:
    chroma_collection = chroma_client.get_collection(collection_name_used)
except:
    chroma_collection = chroma_client.create_collection(collection_name_used)
storage_context = StorageContext.from_defaults(vector_store=ChromaVectorStore(chroma_collection=chroma_collection))
## Create query engine
index = VectorStoreIndex(storage_context=storage_context)
query_engine = index.as_query_engine()

logging.info("DOCUMENTS INDEXED")

prompt_input = input("Enter Prompt ('done' to stop): ")

while(prompt_input != "done"):
    logging.info("PROMPT: %s", prompt_input)

    if (args.verbose):
        logging.info("RETRIEVING CHUNKS")
        retriever = index.as_retriever()
        relevant_docs = retriever.retrieve(prompt_input)
        for result in relevant_docs:
            chunk_data=result.get_text()
            chunk_filename=result.metadata["file_name"]
            logging.info("CHUNK")
            logging.info("FILENAME: %s", chunk_filename)
            logging.info("%s", chunk_data)

    # Build enhanced template
    new_summary_tmpl_str = (
        "Context information is below.\n"
        "---------------------\n"
        "{context_str}\n"
        "---------------------\n"
        "Given the information provided as most important, and when needed leveraging prior knowledge, {type_of_query}"
        "Please generate the response in the style of {personality}.\n"
        "Query: {query_str}\n"
        "Answer: "
    )

    new_summary_tmpl = PromptTemplate(new_summary_tmpl_str)

    new_summary_tmpl_filled = new_summary_tmpl.partial_format(
        type_of_query=args.query_type,
        personality=args.personality_used,
    )

    query_engine.update_prompts(
        {"response_synthesizer:summary_template": new_summary_tmpl_filled}
    )

    logging.info("NEW POMPT TEMPLATE: %s", new_summary_tmpl_filled)

    ## Query
    response = query_engine.query(prompt_input)
    # all_prompts = query_engine.get_prompts()
    # final_prompt_str = all_prompts.get("response_synthesizer")
    # logging.info("FINAL PROMPT STRING: %s", final_prompt_str)
    logging.info("RESPONSE")
    logging.info("%s", response)
    print(response)

    prompt_input = input("Enter Prompt ('done' to stop): ")

logging.info("DONE")