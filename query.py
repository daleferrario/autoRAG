from llama_index.core import VectorStoreIndex, SimpleDirectoryReader, Settings
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.llms.ollama import Ollama

print("Starting")

documents = SimpleDirectoryReader("mlg_data").load_data()

# bge-base embedding model
Settings.embed_model = HuggingFaceEmbedding(model_name="BAAI/bge-base-en-v1.5")

# ollama
Settings.llm = Ollama(model="tinydolphin", request_timeout=600.0)

index = VectorStoreIndex.from_documents(
    documents,
)
print("FIRST RESPONSE")
query_engine = index.as_query_engine()
response = query_engine.query("What is Develop Great Managers all about?")
print(response)

print("SECOND RESPONSE")

query_engine = index.as_query_engine()
response = query_engine.query("What does Develop Great Managers say about preparing for the new normal?")
print(response)

print("THIRD RESPONSE")
response = query_engine.query("What does Develop Great Managers say about not surprising your manager, especially in public?")
print(response)

print("FOURTH RESPONSE")
response = query_engine.query("What does Develop Great Managers say about about where Laura Ortman grew up?")
print(response)

print("DONE")