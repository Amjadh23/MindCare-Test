# CHANGELOG - CodeMap Project Modifications

## Overview

This document provides a **comprehensive guide** to all modifications made to the original [code-map](https://github.com/aida-nabila/code-map) repository. These changes were made to:

1. **Replace OpenAI with Groq** - Use the free Groq API instead of paid OpenAI
2. **Implement Real Pinecone Integration** - Vector database for job matching
3. **Fix Compatibility Issues** - LangChain v2, Windows encoding, CORS
4. **Configure Firebase** - Connect to a new Firebase project

This guide is designed to help the **original developers** understand exactly what was changed, why, and how to integrate these changes into their own environment.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Environment Setup](#environment-setup)
3. [AI Provider Migration (OpenAI → Groq)](#ai-provider-migration-openai--groq)
4. [Pinecone Vector Database Setup](#pinecone-vector-database-setup)
5. [Firebase Configuration](#firebase-configuration)
6. [Bug Fixes & Compatibility](#bug-fixes--compatibility)
7. [File-by-File Changes](#file-by-file-changes)
8. [How to Integrate in Your Project](#how-to-integrate-in-your-project)

---

## Quick Start

### Prerequisites
- Python 3.10+
- Flutter 3.x
- Node.js (for Firebase CLI)
- Groq API Key (free at [console.groq.com](https://console.groq.com))
- Pinecone API Key (free at [pinecone.io](https://pinecone.io))
- Firebase Project

### Running the Project

```bash
# 1. Backend
cd backend
pip install -r requirements.txt  # Or install manually (see below)
python -m uvicorn main:app --host 0.0.0.0 --port 8000

# 2. Frontend
cd ..
flutter pub get
flutter run -d chrome
```

### Required Python Packages
```bash
pip install fastapi uvicorn python-dotenv langchain langchain-groq groq
pip install langchain-core langchain-community langchain-classic
pip install sentence-transformers torch pandas numpy scikit-learn
pip install firebase-admin pinecone
```

---

## Environment Setup

### Backend `.env` File

Create `backend/.env` with the following:

```env
# Groq AI (replaces OpenAI)
GROQ_API_KEY=your_groq_api_key_here

# Pinecone Vector Database
PINECONE_API_KEY=your_pinecone_api_key_here
```

### Frontend `.env` File

Update `assets/.env`:

```env
# For web development (localhost)
BASE_URL=http://localhost:8000

# For Android emulator (original setting)
# BASE_URL=http://10.0.2.2:5000
```

---

## AI Provider Migration (OpenAI → Groq)

### Why Groq?

| Feature | OpenAI | Groq |
|---------|--------|------|
| **Cost** | Paid ($0.03/1K tokens for GPT-4) | Free tier available |
| **Speed** | ~20-50 tokens/sec | ~800 tokens/sec |
| **Model** | GPT-4o | Llama 3.3 70B |
| **API Compatibility** | OpenAI SDK | Similar SDK pattern |

### Changes Made

#### 1. `backend/services/questions_generation_service.py`

**Original Code:**
```python
from langchain_openai import ChatOpenAI
from langchain.prompts import PromptTemplate
from langchain.schema import SystemMessage, HumanMessage

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
llm = ChatOpenAI(model="gpt-4o", temperature=0.2)
```

**Modified Code:**
```python
from langchain_groq import ChatGroq
from langchain_core.prompts import PromptTemplate
from langchain_core.messages import SystemMessage, HumanMessage

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
llm = ChatGroq(model="llama-3.3-70b-versatile", temperature=0.2, groq_api_key=GROQ_API_KEY)
```

**Why these import changes?**
- `langchain.prompts` → `langchain_core.prompts` (LangChain v2 restructuring)
- `langchain.schema` → `langchain_core.messages` (deprecated import path)
- `langchain_openai` → `langchain_groq` (different provider)

#### 2. `backend/services/career_roadmaps_service.py`

Same pattern as above, plus additional error handling:

```python
# Added: Better JSON parsing for LLM responses
if response_text.startswith("```json"):
    response_text = response_text[7:]
if response_text.endswith("```"):
    response_text = response_text[:-3]

# Added: Fallback roadmap when generation fails
return {
    "topics": {"Learning Path": "Basic"},
    "sub_topics": {"Learning Path": ["Review skill gaps", "Practice coding exercises", "Build portfolio projects"]}
}
```

#### 3. `backend/services/embedding_service.py`

**Original Code:**
```python
import openai
client = openai.OpenAI(api_key=OPENAI_API_KEY)

resp = client.chat.completions.create(
    model="gpt-4o",
    messages=[...],
)
```

**Modified Code:**
```python
from groq import Groq
client = Groq(api_key=GROQ_API_KEY)

resp = client.chat.completions.create(
    model="llama-3.3-70b-versatile",
    messages=[...],
)
```

### How to Integrate in Your Project

1. Install Groq packages:
   ```bash
   pip install langchain-groq groq
   ```

2. Get a free API key from [console.groq.com](https://console.groq.com)

3. Replace all instances of:
   - `from langchain_openai import ChatOpenAI` → `from langchain_groq import ChatGroq`
   - `OPENAI_API_KEY` → `GROQ_API_KEY`
   - `ChatOpenAI(model="gpt-4o")` → `ChatGroq(model="llama-3.3-70b-versatile")`

4. Update import paths for LangChain v2 compatibility:
   - `from langchain.prompts` → `from langchain_core.prompts`
   - `from langchain.schema` → `from langchain_core.messages`
   - `from langchain.chains` → `from langchain_classic.chains`

---

## Pinecone Vector Database Setup

### What is Pinecone Used For?

Pinecone stores **job embeddings** as vectors and performs **similarity search** to match users with relevant jobs. When a user completes their profile, their skills are converted to a vector and compared against 8,849 job vectors.

### Creating the Pinecone Index

```python
from pinecone import Pinecone, ServerlessSpec

pc = Pinecone(api_key="your_pinecone_api_key")

# Create index (384 dimensions for MiniLM-L6-v2 embeddings)
pc.create_index(
    name="code-map",
    dimension=384,
    metric="cosine",
    spec=ServerlessSpec(
        cloud="aws",
        region="us-east-1"
    )
)
```

### Uploading Job Embeddings

The job embeddings are pre-generated using HuggingFace's `sentence-transformers/all-MiniLM-L6-v2` model and stored in `backend/data/job_embeddings.pkl`.

```python
import pickle
import pandas as pd
from pinecone import Pinecone

# Load pre-generated embeddings
with open('data/job_embeddings.pkl', 'rb') as f:
    embeddings = pickle.load(f)

# Load job data
df = pd.read_csv('data/jobs.csv')

# Connect to Pinecone
pc = Pinecone(api_key="your_api_key")
index = pc.Index("code-map")

# Upload in batches
batch_size = 100
for i in range(0, len(embeddings), batch_size):
    vectors = []
    for j in range(i, min(i + batch_size, len(embeddings))):
        vectors.append((
            f"job_{j}",
            embeddings[j],
            {
                "title": df.iloc[j]["Title"],
                "description": df.iloc[j]["Full Job Description"][:1000]
            }
        ))
    index.upsert(vectors=vectors, namespace="jobs")
```

### `backend/services/pinecone_service.py` (NEW FILE)

This service handles all Pinecone operations:

```python
class PineconeService:
    def __init__(self, index_name: str = "code-map"):
        self.pc = Pinecone(api_key=os.getenv("PINECONE_API_KEY"))
        self.index = self.pc.Index(index_name)
    
    def query_similar_jobs(self, user_embedding: List[float], top_k: int = 3):
        results = self.index.query(
            vector=user_embedding,
            top_k=top_k,
            include_metadata=True,
            namespace="jobs"
        )
        return [{"id": m.id, "score": m.score, "metadata": m.metadata} for m in results.matches]
```

**Key Features:**
- Automatic fallback to mock data if Pinecone is not configured
- Batch upsert support for uploading embeddings
- Proper error handling with logging

### How to Integrate in Your Project

1. Sign up at [pinecone.io](https://pinecone.io) (free tier: 100K vectors)

2. Install: `pip install pinecone`

3. Create index and upload embeddings (one-time setup):
   ```bash
   python scripts/upload_to_pinecone.py
   ```

4. Add to `.env`:
   ```
   PINECONE_API_KEY=your_key_here
   ```

---

## Firebase Configuration

### Changes Made

#### `lib/main.dart`

**Original Code:**
```dart
await Firebase.initializeApp();
```

**Modified Code:**
```dart
import 'firebase_options.dart';

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

**Why?**
Firebase requires platform-specific configuration. The `firebase_options.dart` file is generated by FlutterFire CLI and contains API keys, project IDs, etc. for each platform.

### How to Set Up Your Own Firebase

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

2. Configure for your project:
   ```bash
   flutterfire configure --project=YOUR_PROJECT_ID
   ```

3. This generates `lib/firebase_options.dart` automatically

4. Get Service Account Key for backend:
   - Firebase Console → Project Settings → Service Accounts
   - Generate new private key
   - Save as `backend/serviceAccountKey.json`

---

## Bug Fixes & Compatibility

### 1. CORS Middleware (Web App Support)

**File:** `backend/main.py`

**Problem:** Flutter web app couldn't connect to backend due to browser CORS policy.

**Solution:**
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### 2. Unicode Encoding (Windows Compatibility)

**Files:** `backend/main.py`, `backend/core/model_loader.py`

**Problem:** Windows console (cp1252 encoding) can't display Unicode checkmark character `✓`.

**Error:**
```
UnicodeEncodeError: 'charmap' codec can't encode character '\u2713'
```

**Solution:**
```python
# Before
print("✓ Server startup complete")

# After
print("[OK] Server startup complete")
```

### 3. LangChain v2 Import Paths

**Problem:** LangChain restructured its packages in v2, breaking old imports.

**Migration Guide:**
| Old Import | New Import |
|------------|------------|
| `from langchain.prompts import PromptTemplate` | `from langchain_core.prompts import PromptTemplate` |
| `from langchain.schema import SystemMessage` | `from langchain_core.messages import SystemMessage` |
| `from langchain.chains import LLMChain` | `from langchain_classic.chains import LLMChain` |
| `from langchain.output_parsers import JsonOutputParser` | `from langchain_core.output_parsers import JsonOutputParser` |

---

## File-by-File Changes

### Modified Files

| File | Changes |
|------|---------|
| `lib/main.dart` | Added `firebase_options.dart` import, added `options:` parameter |
| `assets/.env` | Changed `BASE_URL` from `10.0.2.2:5000` to `localhost:8000` |
| `backend/main.py` | Added CORS middleware, fixed Unicode characters |
| `backend/core/model_loader.py` | Fixed Unicode characters (✓ → [OK]) |
| `backend/services/questions_generation_service.py` | OpenAI → Groq, updated imports |
| `backend/services/career_roadmaps_service.py` | OpenAI → Groq, added error handling |
| `backend/services/embedding_service.py` | OpenAI → Groq |

### New Files

| File | Purpose |
|------|---------|
| `backend/.env` | Environment variables (API keys) |
| `backend/services/pinecone_service.py` | Pinecone vector database integration |
| `lib/firebase_options.dart` | Firebase platform configuration |
| `CHANGELOG.md` | This documentation file |

### Auto-Generated Files (Flutter plugins)

These were modified automatically when Firebase was configured:
- `linux/flutter/generated_plugin_registrant.cc`
- `linux/flutter/generated_plugin_registrant.h`
- `linux/flutter/generated_plugins.cmake`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugin_registrant.h`
- `windows/flutter/generated_plugins.cmake`

---

## How to Integrate in Your Project

### Step 1: Get API Keys

1. **Groq** (free): [console.groq.com](https://console.groq.com)
2. **Pinecone** (free tier): [pinecone.io](https://pinecone.io)
3. **Firebase**: [console.firebase.google.com](https://console.firebase.google.com)

### Step 2: Install Dependencies

```bash
cd backend
pip install langchain-groq groq pinecone firebase-admin
pip install langchain-core langchain-community langchain-classic
```

### Step 3: Create Environment Files

**backend/.env:**
```env
GROQ_API_KEY=gsk_xxxxxxxxxxxxx
PINECONE_API_KEY=pcsk_xxxxxxxxxxxxx
```

**assets/.env:**
```env
BASE_URL=http://localhost:8000
```

### Step 4: Update Import Statements

Find and replace in your Python files:
- `langchain_openai` → `langchain_groq`
- `OPENAI_API_KEY` → `GROQ_API_KEY`
- `gpt-4o` → `llama-3.3-70b-versatile`

### Step 5: Set Up Pinecone

1. Create index named `code-map` (dimension: 384, metric: cosine)
2. Upload job embeddings using provided script
3. Verify with: `index.describe_index_stats()`

### Step 6: Configure Firebase

```bash
flutterfire configure --project=YOUR_PROJECT_ID
```

### Step 7: Run the Project

```bash
# Terminal 1: Backend
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000

# Terminal 2: Frontend
flutter run -d chrome
```

---

## Troubleshooting

### "GROQ_API_KEY not found"
- Ensure `backend/.env` exists and contains `GROQ_API_KEY=...`
- Check that `python-dotenv` is installed

### "No module named 'langchain_groq'"
```bash
pip install langchain-groq
```

### "FirebaseOptions cannot be null"
- Run `flutterfire configure` to generate `firebase_options.dart`
- Import it in `main.dart`

### "CORS policy blocked"
- Ensure CORS middleware is added to `backend/main.py`
- Restart the backend server

### "No matches found in Pinecone"
- Verify index exists: Check [Pinecone Console](https://app.pinecone.io)
- Upload embeddings if index is empty
- Check namespace is `jobs`

---

## Original Repository

- **Source:** https://github.com/aida-nabila/code-map
- **Cloned:** 2025-12-26
- **Modified by:** Automated migration assistant
- **Purpose:** Testing environment with Groq AI and Pinecone

---

## Summary

| Component | Original | Modified |
|-----------|----------|----------|
| AI Provider | OpenAI GPT-4o | Groq Llama 3.3 70B |
| Vector DB | Pinecone (missing service) | Pinecone (full implementation) |
| Cost | Paid APIs | Free tier for both |
| Firebase | Not configured | Configured with options |
| Web Support | CORS blocked | CORS enabled |
| Windows | Unicode errors | ASCII-safe logging |
