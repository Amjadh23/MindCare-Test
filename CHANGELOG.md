# CHANGELOG - CodeMap Project Modifications

This document details all changes made to the original [code-map](https://github.com/aida-nabila/code-map) repository to make it work in a local development environment with Groq AI instead of OpenAI.

---

## Summary of Changes

| Category | Original | Modified |
|----------|----------|----------|
| **AI Provider** | OpenAI GPT-4o | Groq Llama 3.3 70B |
| **Vector Database** | Pinecone (requires API key) | Mock Pinecone (for testing) |
| **Firebase Project** | Original author's project | User's `mindcare-3d015` project |
| **Backend Port** | 5000 | 8000 |
| **Frontend Target** | Android Emulator (`10.0.2.2`) | Web/localhost |

---

## Detailed File Changes

### 1. Flutter Frontend

#### `lib/main.dart`
**Why:** Firebase initialization failed with "FirebaseOptions cannot be null" error.

**Change:**
```dart
// BEFORE (line 6-7):
import 'package:firebase_core/firebase_core.dart';
await Firebase.initializeApp();

// AFTER:
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';  // NEW IMPORT
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,  // NEW PARAMETER
);
```

**Location:** Lines 3-7, 17-20

---

#### `assets/.env`
**Why:** Original pointed to Android emulator IP, needed localhost for web development.

**Change:**
```
# BEFORE:
BASE_URL=http://10.0.2.2:5000

# AFTER:
BASE_URL=http://localhost:8000
```

---

#### `lib/firebase_options.dart` (NEW FILE)
**Why:** Required for Firebase initialization on multiple platforms.

**How created:** Generated using `flutterfire configure --project=mindcare-3d015`

---

### 2. Backend - AI Provider Migration (OpenAI → Groq)

#### `backend/services/questions_generation_service.py`
**Why:** User doesn't have OpenAI API key, using free Groq API instead.

**Changes:**
```python
# BEFORE (lines 5-6):
from langchain_openai import ChatOpenAI
from langchain.prompts import PromptTemplate

# AFTER:
from langchain_groq import ChatGroq
from langchain_core.prompts import PromptTemplate  # Updated import path

# BEFORE (lines 15-17):
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found...")

# AFTER:
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    raise ValueError("GROQ_API_KEY not found...")

# BEFORE (line 22):
llm = ChatOpenAI(model="gpt-4o", temperature=0.2)

# AFTER:
llm = ChatGroq(model="llama-3.3-70b-versatile", temperature=0.2, groq_api_key=GROQ_API_KEY)
```

**Additional fix:** Changed `from langchain.schema import` → `from langchain_core.messages import` (langchain v2 compatibility)

---

#### `backend/services/career_roadmaps_service.py`
**Why:** Same OpenAI → Groq migration + JSON parsing was failing.

**Changes:**
1. Same OpenAI → Groq changes as above
2. Added markdown code block stripping from LLM responses
3. Added fallback roadmap when generation fails:

```python
# NEW (lines 95-98):
# Return fallback roadmap if generation fails
return {
    "topics": {"Learning Path": "Basic"},
    "sub_topics": {"Learning Path": ["Review skill gaps", "Practice coding exercises", "Build portfolio projects"]}
}
```

---

#### `backend/services/embedding_service.py`
**Why:** Uses OpenAI for profile text generation - needed Groq equivalent.

**Changes:**
```python
# BEFORE:
import openai
client = openai.OpenAI(api_key=OPENAI_API_KEY)
model="gpt-4o"

# AFTER:
from groq import Groq
client = Groq(api_key=GROQ_API_KEY)
model="llama-3.3-70b-versatile"
```

---

### 3. Backend - New Files

#### `backend/services/pinecone_service.py` (NEW FILE)
**Why:** Original code imports `PineconeService` which wasn't in the repository (likely in .gitignore). Created mock version for testing.

**What it does:**
- Provides stub methods for Pinecone operations
- Returns mock job data (3 sample jobs) for testing
- Prints warnings when API key is not configured

---

#### `backend/.env` (NEW FILE)
**Why:** Backend requires environment variables for API keys.

**Contents:**
```
GROQ_API_KEY=your_groq_api_key_here
```

---

### 4. Backend - Bug Fixes

#### `backend/main.py`
**Changes:**

1. **Added CORS middleware** (lines 2, 8-15):
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```
**Why:** Flutter web app couldn't connect to backend due to CORS policy.

2. **Fixed Unicode character** (line 32):
```python
# BEFORE:
print("✓ Server startup complete")

# AFTER:
print("[OK] Server startup complete")
```
**Why:** Windows console can't display Unicode checkmark character.

---

#### `backend/core/model_loader.py`
**Changes:** Same Unicode fix (✓ → [OK]) on lines 23, 39, 46, 65.

**Why:** `UnicodeEncodeError` on Windows when printing checkmark symbols.

---

### 5. Auto-Generated Files (Flutter)

These files were automatically modified by Flutter when adding Firebase:
- `linux/flutter/generated_plugin_registrant.cc`
- `linux/flutter/generated_plugin_registrant.h`
- `linux/flutter/generated_plugins.cmake`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugin_registrant.h`
- `windows/flutter/generated_plugins.cmake`

---

## Dependencies Installed

```bash
# Python packages added:
pip install langchain-groq groq firebase-admin langchain-community

# Already installed but updated imports for:
langchain, langchain-core, langchain-openai, sentence-transformers, torch
```

---

## How to Run

### Backend:
```bash
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

### Frontend:
```bash
flutter run -d chrome
```

---

## Known Limitations

1. **Mock Pinecone:** Job matching uses mock data, not real vector search
2. **Firebase Index Required:** Some queries need composite indexes created in Firebase Console
3. **Groq Rate Limits:** Free tier has limits on API calls per minute

---

## Original Repository

- **Source:** https://github.com/aida-nabila/code-map
- **Cloned:** 2025-12-26
