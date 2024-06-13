from llama_index.llms.ollama import Ollama
from pathlib import Path
from llama_index.core import VectorStoreIndex, ServiceContext, SimpleDirectoryReader, StorageContext, Settings, PromptTemplate
from llama_index.vector_stores.chroma import ChromaVectorStore
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
import sys, datetime, logging, warnings, chromadb, os, argparse, subprocess

# Usage: PROGRAM [-v --local -d <data_directory> -e <embedding_model> -c <chunk_size> -o <chunk_overlap> -p <personality_used> -t <query_type> -l <llm>]
# Usage: PROGRAM [-v --local -d <data_directory> -e <embedding_model> -c <chunk_size> -o <chunk_overlap> -p <personality_used> -t <query_type> -l <tinydolphin | llama3 | tinyllama>]
# All arguments are optional
# -v is included to turn on logging at the INFO level, saving to a log file
# --local is included if running locally
# -d <data_directory> is a directory, default is "/data"
# -e <embedding_model> is a model from HuggingFace, default is "BAAI/bge-base-en-v1.5"
# -c <chunk_size> is a number, default is 1024 (tokens)
# -o <chunk_overlap> is a number, default is 20 (tokens)
# -p <personality_used> is a sentence or paragraph, default is an experienced manager
# -q <query_type> is an incomplete sentence:), default is "answer the query", another good option is "comment on a post"
# -l <llm> is a large learning model, default is tinydolphin

def parse_args():
  """Parses arguments from the command line."""
  parser = argparse.ArgumentParser(description="Program description")
  parser.add_argument("-v", "--verbose", action="store_true", help="Turn on INFO level logging")
  parser.add_argument("--local", action="store_true", help="Indicate program is running locally")
  parser.add_argument("-d", "--data_directory", type=str, default="/data", help="Data directory path")
  parser.add_argument("-e", "--embedding_model", type=str, default="BAAI/bge-base-en-v1.5", help="Embedding model from HuggingFace")
  parser.add_argument("-c", "--chunk_size", type=int, default=1024, help="Chunk size in tokens")
  parser.add_argument("-o", "--chunk_overlap", type=int, default=20, help="Chunk overlap in tokens")
  parser.add_argument("-p", "--personality_used", type=str, default="Respond as an experienced manager who has had employees around the world, has delivered large projects, has worked with other managers and leaders, has seen lots of HR related issues and challenges, and has a good grasp of all management related disciplines", help="Personality used")
  parser.add_argument("-t", "--query_type", type=str, default="answer the query", help="Query type")
  parser.add_argument("-l", "--llm", type=str, default="tinydolphin", help="Large language model")
  return parser.parse_args()

args = parse_args()

print("STARTING")

# If -v then turn on logging at INFO level, log to a file
if args.verbose:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        filename="dgm.log",
    )

def warning_to_log(message, category, filename, lineno, file=None, line=None):
    log = logging.getLogger('py.warnings')
    log.warning('%s:%s: %s:%s', filename, lineno, category.__name__, message)

# Redirect warnings to the logging module
warnings.showwarning = warning_to_log

# Print or use the parsed arguments here
logging.info("ARGUMENTS")
logging.info(f"verbose: {args.verbose}")
logging.info(f"local: {args.local}")
logging.info(f"data_directory: {args.data_directory}")
logging.info(f"embedding_model: {args.embedding_model}")
logging.info(f"chunk_size: {args.chunk_size}")
logging.info(f"chunk_overlap: {args.chunk_overlap}")
logging.info(f"personality_used: {args.personality_used}")
logging.info(f"query_type: {args.query_type}")
logging.info(f"llm: {args.llm}")

logging.info("STARTING")

# Set up
llm_model_used = args.llm
document_directory_used = args.data_directory
embedding_model_used = args.embedding_model
collection_name_used = "dgm_data"
chunk_size_used = args.chunk_size
chunk_overlap_used = args.chunk_overlap
personality_used = args.personality_used
type_of_query_used= args.query_type

# Set embeddings model
Settings.embed_model = HuggingFaceEmbedding(model_name=embedding_model_used)

# Load data
documents = SimpleDirectoryReader(document_directory_used).load_data()
documents_loaded=len(documents)
logging.info("DOCUMENTS LOADED: %d", documents_loaded)

# Create ChromaDB
chroma_client = None
if not args.local:
    chroma_client = chromadb.EphemeralClient()
else:
    chroma_client = chromadb.HttpClient(host=os.getenv('HOST', 'localhost'), port=8000)
chroma_collection = None
try:
    # Attempt to get the existing collection
    chroma_collection = chroma_client.get_collection(collection_name_used)
except:
    # If the collection doesn't exist, create it
    chroma_collection = chroma_client.create_collection(collection_name_used)
vector_store = ChromaVectorStore(chroma_collection=chroma_collection)
storage_context = StorageContext.from_defaults(vector_store=vector_store)

logging.info("CHROMADB CREATED")

# Load the LLM model that will be used
result = subprocess.run(f"ollama pull {llm_model_used}", shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
if result.returncode == 0:
    output = result.stdout.decode("utf-8")
    logging.info(f"COMMAND SUCCEEDED: ollama pull {llm_model_used}")
else:
    logging.info(f"COMMAND FAILED: ollama pull {llm_model_used}"))
 
## Initialize Ollama and ServiceContext, using the requested LLM model
Settings.llm = Ollama(model=llm_model_used, request_timeout=600.0)
Settings.chunk_size=chunk_size_used
Settings.chunk_overlap=chunk_overlap_used

logging.info("OLLAMA SERVICES INITIALIZED")

## Llama Index
index = VectorStoreIndex.from_documents(documents, storage_context=storage_context)
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
        type_of_query=type_of_query_used,
        personality=personality_used,
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