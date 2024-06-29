from flask import Flask, request, jsonify
from llama_index.llms.ollama import Ollama
from llama_index.core import VectorStoreIndex, Settings, PromptTemplate
from llama_index.vector_stores.chroma import ChromaVectorStore
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from ollama import Client
import chromadb
import logging
import os

# Configure logging
logging.basicConfig(level=logging.INFO)

# Environment Variables
collection_name = os.getenv("CUSTOMER_ID")
personality_used = os.getenv("PERSONALITY_USED")
query_scope = os.getenv("QUERY_SCOPE")

# Local Variables
llama_index_port = 8001
chromadb_port = 8000
model = "llama3"
ollama_port = 11434
ollama_host = "ollama"
ollama_request_timeout = 600.0
embedding_model_name = "BAAI/bge-base-en-v1.5"
query_type = "answer the query"
chromadb_host="chromadb"
# personality_used = "an experienced manager who has had employees around the world, has delivered large projects, has worked with other managers and leaders, has seen lots of HR related issues and challenges, and has a good grasp of all management related disciplines"
# query_scope = "Given the information provided as most important, and when needed leveraging prior knowledge"

embed_model = HuggingFaceEmbedding(model_name=embedding_model_name)
# Ollama settings
Settings.llm = Ollama(model=model, request_timeout=ollama_request_timeout, base_url=f"http://{ollama_host}:{ollama_port}")

app = Flask(__name__)
query_engine = None

def setup():
    ollama_client = Client(host=f'http://{ollama_host}:{ollama_port}')
    ollama_client.pull(model)
    # Create index from existing ChromaDB collection
    chroma_client = chromadb.HttpClient(host=chromadb_host, port=chromadb_port)
    vector_store = ChromaVectorStore(chroma_collection=chroma_client.get_collection(collection_name))
    index = VectorStoreIndex.from_vector_store(vector_store=vector_store, embed_model=embed_model)

    # Create query engine
    query_engine = index.as_query_engine()

    # Update template
    new_summary_tmpl_str = (
        "Context information is below.\n"
        "---------------------\n"
        "{context_str}\n"
        "---------------------\n"
        f"{query_scope}, {query_type}. "
        f"Please generate the response in the style of {personality_used}.\n"
        "Query: {query_str}\n"
        "Answer: "
    )

    new_summary_tmpl = PromptTemplate(new_summary_tmpl_str)

#    new_summary_tmpl_filled = new_summary_tmpl.partial_format(
#        type_of_query=query_type,
#        personality=personality_used,
#    )

    query_engine.update_prompts(
        {"response_synthesizer:summary_template": new_summary_tmpl}
    )
    logging.info("Query engine setup completed successfully.")
    return query_engine

@app.route('/query', methods=['GET'])
def get_text():
    text = request.args.get('question')

    if text:
        try:
            response_text = app.config['QUERY_ENGINE'].query(text)
            logging.info(response_text)
            response = {
                'received_text': text,
                'message': response_text.response,
            }
        except Exception as e:
            logging.error(f"Query processing failed: {e}")
            response = {
                'error': 'Failed to process query'
            }
    else:
        response = {
            'error': 'No text provided'
        }
    logging.info(response)
    return jsonify(response)

if __name__ == '__main__':
    app.config['QUERY_ENGINE'] = setup()
    app.run(debug=True, host='0.0.0.0', port=llama_index_port)