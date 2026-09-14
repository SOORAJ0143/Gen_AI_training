# ==============================================================================
# ENTERPRISE RAG APPLICATION (app.py)
# Run via terminal: streamlit run app.py
# ==============================================================================
import os
import streamlit as st
import chromadb
from chromadb.api.types import Documents, EmbeddingFunction, Embeddings
from pypdf import PdfReader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from dotenv import load_dotenv

# Official Google GenAI SDK
from google import genai
from google.genai import types

# Load environment variables (API Key)
load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# Initialize Gemini Client
if not GEMINI_API_KEY:
    st.error("🚨 GEMINI_API_KEY missing. Please add it to your .env file.")
    st.stop()

client = genai.Client(api_key=GEMINI_API_KEY)


# ==============================================================================
# CUSTOM EMBEDDING FUNCTION & UI SHELL
# ==============================================================================
class GeminiEmbeddingFunction(EmbeddingFunction):
    """Custom ChromaDB embedding function using Google Gemini text-embedding-004"""

    def __call__(self, input: Documents) -> Embeddings:
        response = client.models.embed_content(
            model="text-embedding-004",
            contents=input
        )
        return [emb.values for emb in response.embeddings]


# Streamlit Page Config
st.set_page_config(page_title="Enterprise RAG Assistant", page_icon="📚", layout="wide")
st.title("📚 Secure Enterprise Document RAG")
st.markdown("Upload a PDF document and ask questions. The AI will cite its sources.")

# Initialize Session State Variables
if "messages" not in st.session_state:
    st.session_state.messages = []
if "collection" not in st.session_state:
    st.session_state.collection = None

# --- SIDEBAR: DOCUMENT INGESTION ---
with st.sidebar:
    st.header("📄 Document Ingestion")
    uploaded_file = st.file_uploader("Upload a PDF", type="pdf")

    if uploaded_file is not None and st.session_state.collection is None:
        with st.spinner("Parsing and chunking document..."):
            # 1. Read PDF
            reader = PdfReader(uploaded_file)
            raw_text = "".join([page.extract_text() + "\n" for page in reader.pages])

            # 2. Chunk Text
            splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=100)
            chunks = splitter.split_text(raw_text)

            # 3. Initialize Ephemeral ChromaDB
            chroma_client = chromadb.Client()
            collection = chroma_client.create_collection(
                name="temp_doc_db",
                embedding_function=GeminiEmbeddingFunction()
            )

            # 4. Ingest
            ids = [f"chunk_{i}" for i in range(len(chunks))]
            metadatas = [{"source": uploaded_file.name, "chunk": i} for i in range(len(chunks))]
            collection.add(documents=chunks, ids=ids, metadatas=metadatas)

            st.session_state.collection = collection
            st.success(f"✅ Indexed {len(chunks)} chunks successfully!")

# --- DISPLAY CHAT HISTORY ---
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])
        if "sources" in msg:
            with st.expander("View Retrieved Sources"):
                for source in msg["sources"]:
                    st.info(source)

# ==============================================================================
# 🎓 STUDENT LAB WORKSPACE: RETRIEVAL, GUARDRAILS & GENERATION
# ==============================================================================
prompt = st.chat_input("Ask a question about your document...")

if prompt:
    if st.session_state.collection is None:
        st.warning("Please upload a PDF first.")
        st.stop()

    # Show user message
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)

    # ------------------------------------------------------------------
    # TODO 1: Retrieve Context from the Vector Database
    # ------------------------------------------------------------------
    results = st.session_state.collection.query(
        query_texts=[prompt],
        n_results=3
    )

    retrieved_docs = results["documents"][0]
    retrieved_metadatas = results["metadatas"][0]

    # Format retrieved chunks into a context string and a source list
    context_text = ""
    source_list = []
    for i, (doc, meta) in enumerate(zip(retrieved_docs, retrieved_metadatas)):
        chunk_num = meta.get("chunk", i)
        context_text += f"[Chunk {chunk_num}]\n{doc}\n\n"
        source_list.append(f"[Chunk {chunk_num}] ({meta.get('source', 'unknown')}): {doc[:200]}...")

    # ------------------------------------------------------------------
    # TODO 2: Build the Guardrailed Prompt Template
    # ------------------------------------------------------------------
    system_instruction = (
        "You are a strict Enterprise Q&A Assistant. "
        "You must answer the user's question ONLY using the information provided "
        "in the CONTEXT section below. Do not use any outside knowledge.\n\n"
        "Guardrail 1: Only use facts explicitly present in the provided context.\n"
        "Guardrail 2: If the answer is not contained in the context, explicitly state: "
        "'I cannot answer this based on the provided documents.' Do NOT hallucinate.\n"
        "Guardrail 3: When making a claim, cite the chunk number inline, e.g. [Chunk 1]."
    )

    user_payload = (
        f"CONTEXT:\n{context_text}\n"
        f"QUESTION:\n{prompt}"
    )

    # ------------------------------------------------------------------
    # TODO 3: Execute the LLM Generation
    # ------------------------------------------------------------------
    with st.chat_message("assistant"):
        try:
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=user_payload,
                config=types.GenerateContentConfig(
                    system_instruction=system_instruction,
                    temperature=0.0
                )
            )
            final_answer = response.text

            st.markdown(final_answer)
            with st.expander("View Retrieved Sources"):
                for source in source_list:
                    st.info(source)

            st.session_state.messages.append({
                "role": "assistant",
                "content": final_answer,
                "sources": source_list
            })

        except Exception as e:
            error_msg = f"⚠️ An error occurred while generating a response: {e}"
            st.error(error_msg)
            st.session_state.messages.append({"role": "assistant", "content": error_msg})