import os
import glob
import pickle
import pandas as pd
import uuid
from tqdm import tqdm
from dotenv import load_dotenv
from pinecone import Pinecone
from transformers import AutoTokenizer, AutoModel
import torch

# =====================================
# Load API Key from .env
# =====================================
load_dotenv()
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
if not PINECONE_API_KEY:
    raise ValueError("Missing PINECONE_API_KEY in .env file")

# =====================================
# Configurations
# =====================================
INDEX_NAME = "code-map"  # Your Pinecone index name
FOLDER_PATH = "../data"  # Folder containing CSVs
COLUMN_NAME = "Full Job Description"  # Column to embed
BATCH_SIZE = 100  # Number of vectors per upload batch
EMBEDDINGS_FILE = os.path.join(FOLDER_PATH, "job_embeddings.pkl")

# =====================================
# Initialize Hugging Face Model
# =====================================
print("Loading Hugging Face model...")
hf_model_name = "sentence-transformers/all-MiniLM-L6-v2"
tokenizer = AutoTokenizer.from_pretrained(hf_model_name)
model = AutoModel.from_pretrained(hf_model_name)
print("✓ Model loaded successfully\n")


def get_embeddings(text: str):
    """Return embedding as a list of floats."""
    inputs = tokenizer(text, return_tensors="pt", truncation=True, padding=True)
    with torch.no_grad():
        outputs = model(**inputs)
    emb = outputs.last_hidden_state.mean(dim=1)
    return emb.squeeze(0).cpu().numpy().tolist()


# =====================================
# Load All Job CSVs
# =====================================
csv_files = glob.glob(f"{FOLDER_PATH}/*.csv")
dfs = []

for file in csv_files:
    try:
        df_temp = pd.read_csv(file)
        if not df_temp.empty:
            dfs.append(df_temp)
            print(f"✓ Loaded {len(df_temp)} records from {file}")
    except Exception as e:
        print(f"Skipping {file} due to error: {e}")

if not dfs:
    raise ValueError("No CSV files found or all were empty.")

df = pd.concat(dfs, ignore_index=True)
print(f"\nTotal combined job records: {len(df)}")

# =====================================
# Data Cleaning (critical!)
# =====================================
# Replace NaN, None, etc. with empty strings
df = df.fillna("")

# Ensure all columns are string-typed to avoid NaN/float issues in metadata
df = df.astype(str)

print("✓ Cleaned dataframe: NaN and invalid values replaced.\n")

# =====================================
# Connect to Pinecone
# =====================================
print("Connecting to Pinecone...")
pc = Pinecone(api_key=PINECONE_API_KEY)
index = pc.Index(INDEX_NAME)
print(f"✓ Connected to Pinecone index: {INDEX_NAME}\n")

# =====================================
# Generate and Upload Embeddings
# =====================================
job_descriptions = df[COLUMN_NAME].astype(str)
embeddings = []
batch = []

print("Generating and uploading embeddings...\n")

for i, job_desc in enumerate(tqdm(job_descriptions, desc="Processing jobs")):
    try:
        emb = get_embeddings(job_desc)
        embeddings.append(emb)

        # Safe metadata (all strings)
        vector_id = str(uuid.uuid4())
        metadata = {"title": df.iloc[i].get("Title", ""), "description": job_desc}

        # Force clean metadata (ensure valid JSON)
        metadata = {k: ("" if pd.isna(v) else str(v)) for k, v in metadata.items()}

        batch.append({"id": vector_id, "values": emb, "metadata": metadata})

        # Upload in batches
        if len(batch) >= BATCH_SIZE:
            index.upsert(vectors=batch)
            batch = []

    except Exception as e:
        print(f"Skipping record {i} due to error: {e}")
        continue

# Upload remaining
if batch:
    index.upsert(vectors=batch)

# Save embeddings locally
with open(EMBEDDINGS_FILE, "wb") as f:
    pickle.dump(embeddings, f)

print(
    f"\nDone! Uploaded {len(df)} embeddings to Pinecone and saved backup at {EMBEDDINGS_FILE}"
)
