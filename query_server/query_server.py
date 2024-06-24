from flask import Flask, request, jsonify
from llama_index.llms.ollama import Ollama
from llama_index.core import VectorStoreIndex, Settings, PromptTemplate
from llama_index.vector_stores.chroma import ChromaVectorStore
import chromadb
import logging
import os

# Configure logging
logging.basicConfig(level=logging.INFO)

# Environment Variables
collection_name = os.getenv("CUSTOMER_ID")

# Local Variables
llama_index_port = 8000
chromadb_port = 8000
model = "llama3"
ollama_request_timeout = 600.0
query_type = "answer the query"
personality_used = "an experienced manager who has had employees around the world, has delivered large projects, has worked with other managers and leaders, has seen lots of HR related issues and challenges, and has a good grasp of all management related disciplines"

# Ollama settings
Settings.llm = Ollama(model=model, request_timeout=ollama_request_timeout)

app = Flask(__name__)
query_engine = None

def setup():
    global query_engine
    try:
        # Create index from existing ChromaDB collection
        chroma_client = chromadb.HttpClient(host=host, port=chromadb_port)
        vector_store = ChromaVectorStore(chroma_collection=chroma_client.get_collection(collection_name))
        index = VectorStoreIndex.from_vector_store(vector_store=vector_store)

        # Create query engine
        query_engine = index.as_query_engine()

        # Update template
        new_summary_tmpl_str = (
            "Context information is below.\n"
            "---------------------\n"
            "{context_str}\n"
            "---------------------\n"
            "Given the information provided as most important, and when needed leveraging prior knowledge, {type_of_query}. "
            "Please generate the response in the style of {personality}.\n"
            "Query: {query_str}\n"
            "Answer: "
        )

        new_summary_tmpl = PromptTemplate(new_summary_tmpl_str)

        new_summary_tmpl_filled = new_summary_tmpl.partial_format(
            type_of_query=query_type,
            personality=personality_used,
        )

        query_engine.update_prompts(
            {"response_synthesizer:summary_template": new_summary_tmpl_filled}
        )
        logging.info("Query engine setup completed successfully.")
    except Exception as e:
        logging.error(f"Failed to set up query engine: {e}")

@app.route('/query', methods=['GET'])
def get_text():
    global query_engine
    text = request.args.get('question')

    if text:
        try:
            response_text = query_engine.query(text)
            response = {
                'received_text': text,
                'message': response_text,
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
    return jsonify(response)

if __name__ == '__main__':
    setup()
    app.run(debug=True, host='0.0.0.0', port=llama_index_port)
