import glob
import os
import re
import pickle
import json
from typing import Any, Dict, List
from dotenv import load_dotenv
import openai
import pandas as pd
from sqlalchemy.orm import Session
import torch
from transformers import AutoTokenizer, AutoModel
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np

from core.database import SessionLocal
from models.assessment import (
    FollowUpAnswers,
    GeneratedQuestion,
    UserTest,
    UserSkillsKnowledge,
)
from services.scoring_service import calculate_score

# -----------------------------
# Env & OpenAI client
# -----------------------------
load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found. Please set it in your .env file.")

client = openai.OpenAI(api_key=OPENAI_API_KEY)

# -----------------------------
# Global variables - Now initialized as None
# -----------------------------
_tokenizer = None
_model = None
df = pd.DataFrame()
job_embeddings = []

def initialize_ai_models():
    """Initialize AI models and load job data - call this on server startup"""
    global _tokenizer, _model, df, job_embeddings
    
    print("Initializing AI models...")
    
    # Load HF model
    hf_model_name = "sentence-transformers/all-MiniLM-L6-v2"
    _tokenizer = AutoTokenizer.from_pretrained(hf_model_name)
    _model = AutoModel.from_pretrained(hf_model_name)
    print("✓ HuggingFace model loaded")
    
    # Load job data
    folder_path = "data"
    csv_files = glob.glob(f"{folder_path}/*.csv")
    dfs: List[pd.DataFrame] = []

    for file in csv_files:
        try:
            df_temp = pd.read_csv(file)
            if not df_temp.empty:
                dfs.append(df_temp)
        except pd.errors.EmptyDataError:
            print(f"Skipping empty file: {file}")
            continue

    if dfs:
        df = pd.concat(dfs, ignore_index=True)
        print(f"✓ Loaded {len(df)} job records")
        
        # Try to load pre-generated embeddings
        embeddings_file = os.path.join(folder_path, "job_embeddings.pkl")
        if os.path.exists(embeddings_file):
            print("Loading pre-generated embeddings...")
            try:
                with open(embeddings_file, 'rb') as f:
                    job_embeddings = pickle.load(f)
                print(f"✓ Loaded {len(job_embeddings)} pre-generated embeddings")
            except Exception as e:
                print(f"Error loading embeddings: {e}. Regenerating...")
                job_embeddings = _generate_and_save_embeddings(df, embeddings_file)
        else:
            # Generate and save embeddings for first time
            job_embeddings = _generate_and_save_embeddings(df, embeddings_file)
    else:
        print("No valid data found in CSV files.")
        df = pd.DataFrame()
    
    print("✓ Server startup complete - Ready for requests!")

def _generate_and_save_embeddings(df, embeddings_file):
    """Generate embeddings and save to file"""
    print("Generating embeddings for all job descriptions...")
    print("This will take a while (5-15 minutes)...")
    
    job_descriptions = df["Full Job Description"].astype(str)
    
    # Show progress
    total = len(job_descriptions)
    embeddings = []
    
    for i, job_desc in enumerate(job_descriptions):
        if i % 100 == 0:  # Print progress every 100 jobs
            print(f"Processing {i}/{total} jobs...")
        embeddings.append(get_embeddings(job_desc))
    
    # Save to file
    try:
        with open(embeddings_file, 'wb') as f:
            pickle.dump(embeddings, f)
        print(f"✓ Saved {len(embeddings)} embeddings to {embeddings_file}")
    except Exception as e:
        print(f"Error saving embeddings: {e}")
    
    return embeddings

# -----------------------------
# Helper function to check if models are loaded
# -----------------------------
def _ensure_models_loaded():
    """Ensure models are loaded before using them"""
    if _tokenizer is None or _model is None:
        raise Exception("AI models not initialized. Call initialize_ai_models() first.")

# -----------------------------
# HF encoder for embeddings
# -----------------------------
def get_embeddings(text: str):
    """
    Turn text into an embedding using the HF model.
    Returns a Python list (JSON-serializable).
    """
    _ensure_models_loaded()
    
    inputs = _tokenizer(text, return_tensors="pt", truncation=True, padding=True)
    with torch.no_grad():
        outputs = _model(**inputs)
    # Simple mean pooling
    emb = outputs.last_hidden_state.mean(dim=1)  # [1, hidden]
    return emb.squeeze(0).cpu().numpy().tolist()

# -----------------------------
# OpenAI call function
# -----------------------------
def call_openai(prompt: str, max_tokens=2000, temperature=0.2) -> str:
    """
    Generate a descriptive profile text from OpenAI based on a prompt.
    """
    resp = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "system",
                "content": (
                    "You are an assistant that returns clean, concise outputs. "
                    "Write in a professional, neutral tone; avoid buzzwords."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        max_tokens=max_tokens,
        temperature=temperature,
    )
    return resp.choices[0].message.content.strip()

def normalize_option(opt: str) -> str:
    if not opt:
        return ""
    match = re.match(r'([A-Z])', opt.strip().upper())
    return match.group(1) if match else opt.strip().upper()

# -----------------------------
# Data aggregation for a user
# -----------------------------
def get_user_embedding_data(user_test_id: int) -> Dict[str, Any]:
    """
    Fetch user responses and follow-up results; compute score; build combined_data.
    score reflects how consistent/true the skillReflection is relative to follow-up answers.
    """
    db: Session = SessionLocal()
    try:
        # 1) Fetch user responses (ORM model)
        user_res = (
            db.query(UserTest).filter(UserTest.id == user_test_id).first()
        )
        if not user_res:
            return {"error": f"No user responses found for user_test_id {user_test_id}"}

        # 2) Fetch follow-up answers
        follow_ups = (
            db.query(FollowUpAnswers)
            .filter(FollowUpAnswers.user_test_id == user_test_id)
            .all()
        )

        # 3) Build results for scoring
        results: List[Dict[str, Any]] = []
        for f in follow_ups:
            correct_q = (
                db.query(GeneratedQuestion)
                .filter(GeneratedQuestion.id == f.question_id)
                .first()
            )
            
            # Compare user's selected answer with correct answer from database
            is_correct = bool(
               correct_q and 
               normalize_option(correct_q.answer) == normalize_option(f.selected_option)
            )
  
            results.append(
                {
                    "question_id": f.question_id,               # from FollowUpAnswers
                    "question_text": correct_q.question_text if correct_q else None,  # from GeneratedQuestion
                    "selected_option": f.selected_option,       # from FollowUpAnswers
                    "correct_answer": correct_q.answer if correct_q else None,  # from GeneratedQuestion
                    "is_correct": is_correct,                   # computed by comparing selected vs answer
                }
            )

        # 4) Calculate score (how true the skill reflection is)
        score_result = calculate_score(results)

        # 5) Normalize programmingLanguages to a list (in case stored as JSON/text)
        prog_langs = user_res.programmingLanguages
        if isinstance(prog_langs, str):
            # naive split fallback; replace with json.loads if you store JSON text
            prog_langs = [p.strip() for p in prog_langs.split(",") if p.strip()]

        # 6) Build combined data for downstream AI analysis
        combined_data = {
            "user_test_id": user_test_id,
            "user_responses": {
                "educationLevel": getattr(user_res, "educationLevel", None),
                "cgpa": getattr(user_res, "cgpa", None),
                "major": getattr(user_res, "major", None),
                "programmingLanguages": prog_langs,
                "courseworkExperience": getattr(user_res, "courseworkExperience", None),
                "skillReflection": getattr(user_res, "skillReflection", None),
            },
            "follow_up_results": results,
            "score": score_result["score_percentage"], # Extract the numeric score
        }
        return combined_data
    finally:
        db.close()

# -----------------------------
# Analyze user skills & knowledge
# -----------------------------
def analyze_user_skills_knowledge(user_test_id: int) -> Dict[str, Any]:
    combined_data = get_user_embedding_data(user_test_id)
    if "error" in combined_data:
        return combined_data

    prompt = f"""
    Analyze the student's profile data below.

    INPUT DATA:
    {combined_data}

    TASK:
    - Extract all TECHNICAL SKILLS from the user's skillReflection and follow-up answers.
    - Assign a SKILL LEVEL for each: Basic, Intermediate, or Advanced.
    - Extract all KNOWLEDGE AREAS (subject domains, concepts, methodologies) from the user's courseworkExperience and follow-up answers.
    - Assign a KNOWLEDGE LEVEL for each: Basic, Intermediate, or Advanced.
    - Be as specific as possible: if a skill or knowledge area is mentioned in context (e.g., 'Python with Django'), include both Python and Django separately.
    - Include all skills and knowledge mentioned across answers, even if implied.

    OUTPUT RULES:
    - Respond STRICTLY in JSON format with exactly two keys: "skills" and "knowledge".
    - Each key should map names to levels.
    - Remove duplicates and keep the most specific term.
    - Do NOT include explanations, comments, or markdown code blocks.
    - Example:
    {{
        "skills": {{"Python": "Intermediate", "Communication": "Beginner"}},
        "knowledge": {{"Algorithms": "Beginner", "Database Systems": "Expert"}}
    }}
    - DO NOT use markdown code blocks
    """

    try:
        response = call_openai(prompt, max_tokens=500, temperature=0.2)
        cleaned_response = response.strip()

        # Remove code block markers if present
        if cleaned_response.startswith('```json'):
            cleaned_response = cleaned_response[7:]
        elif cleaned_response.startswith('```'):
            cleaned_response = cleaned_response[3:]
        if cleaned_response.endswith('```'):
            cleaned_response = cleaned_response[:-3]
        cleaned_response = cleaned_response.strip()

        # Parse JSON
        result = json.loads(cleaned_response)

        # Store as JSON dicts
        skills_dict = result.get("skills", {})
        knowledge_dict = result.get("knowledge", {})

        # Save to DB
        db = SessionLocal()
        try:
            existing_entry = db.query(UserSkillsKnowledge).filter(
                UserSkillsKnowledge.user_test_id == user_test_id
            ).first()

            if existing_entry:
                existing_entry.skills = skills_dict
                existing_entry.knowledge = knowledge_dict
                print(f"Updated existing entry for user_test_id {user_test_id}")
            else:
                entry = UserSkillsKnowledge(
                    user_test_id=user_test_id,
                    skills=skills_dict,
                    knowledge=knowledge_dict,
                )
                db.add(entry)
                print(f"Created new entry for user_test_id {user_test_id}")

            db.commit()
            print(f"Successfully saved skills/knowledge for user_test_id {user_test_id}")
            return {"skills": skills_dict, "knowledge": knowledge_dict}

        except Exception as db_error:
            db.rollback()
            print(f"Database error: {db_error}")
            return {"error": f"Database error: {str(db_error)}"}
        finally:
            db.close()

    except Exception as e:
        error_msg = f"Failed to analyze skills/knowledge: {str(e)}. Response: {cleaned_response if 'cleaned_response' in locals() else 'No response'}"
        print(error_msg)
        return {"error": error_msg}
    
# -----------------------------
# Profile generation via OpenAI
# -----------------------------
def _build_profile_prompt(combined_data: Dict[str, Any]) -> str:
    """
    Build a clear instruction that explains how to use score:
    score = how consistent/true the user's skillReflection is vs. follow-up test.
    """
    return (
        "Analyze the following user information and write a thorough, objective profile. "
        "Focus on strengths, weaknesses, practical skills, and realistic next steps. "
        "Interpret 'score' as the degree to which the user's skillReflection is confirmed "
        "by follow-up test answers (higher = more accurate self-assessment). "
        "Avoid fluff; keep it evidence-based and specific.\n\n"
        f"USER DATA:\n{combined_data}\n\n"
        "IMPORTANT FORMATTING RULES:\n"
        "1. Return exactly ONE descriptive paragraph\n"
        "2. Use bullet-style clauses separated by semicolons ONLY\n"
        "3. Each clause should be concise and complete\n"
        "4. Do not use markdown formatting, asterisks, or other symbols\n"
        "5. Example format: 'Strong in Java and Python; Experienced with ML frameworks; Excellent communication skills;'\n"
        "6. Ensure the response can be easily parsed by splitting on semicolons"
    )

def generate_user_profile_text(combined_data: Dict[str, Any]) -> str:
    prompt = _build_profile_prompt(combined_data)
    return call_openai(prompt)


# -----------------------------
# Create user embedding
# -----------------------------
def create_user_embedding(user_test_id: int) -> Dict[str, Any]:
    """
    1) Collect combined_data (user responses + follow-up results + score)
    2) Generate descriptive profile text via OpenAI
    3) Convert profile text into an embedding via HF encoder
    """
    combined_data = get_user_embedding_data(user_test_id)
    if "error" in combined_data:
        return combined_data

    profile_text = generate_user_profile_text(combined_data)
    user_embedding = get_embeddings(profile_text)

    return {
        "user_test_id": user_test_id,
        "profile_text": profile_text,
        "user_embedding": user_embedding,  # list[float]
        "combined_data": combined_data,  # included for debugging/inspection
    }

# -----------------------------
# Match user to job 
# -----------------------------
def match_user_to_job(
    user_test_id: int,
    user_embedding: List[float], 
    use_openai_summary: bool = True,
) -> Dict[str, Any]:
    """
    Compare user embedding to all job embeddings using cosine similarity.
    df and job_embeddings are now global, no need to pass them.
    """

    global df, job_embeddings  # use the global variables defined when loading CSVs

    if df.empty or not job_embeddings:
        return {"error": "No jobs or embeddings available."}

    # Convert to numpy
    user_vec = np.array(user_embedding).reshape(1, -1)  # (1, dim)
    job_matrix = np.array(job_embeddings)  # (num_jobs, dim)

    # Compute cosine similarity
    similarities = cosine_similarity(user_vec, job_matrix)[0]  # shape: (num_jobs,)

    # Get indices of top 3 jobs (sorted by similarity score)
    top_n = min(3, len(similarities))
    
    # Get sorted indices
    sorted_indices = np.argsort(similarities)[::-1]  # highest first

    # Deduplicate by job title before slicing
    seen_titles = set()
    unique_indices = []
    for idx in sorted_indices:
        title = df.iloc[idx].get("Title", "N/A")
        if title not in seen_titles:
            seen_titles.add(title)
            unique_indices.append(idx)
        if len(unique_indices) >= top_n:
            break
    
    # Use unique_indices (deduplicated & limited to top_n)
    top_matches = []
    
    def clean_openai_json(raw_text: str) -> str:
        """Remove code blocks or extra whitespace from OpenAI response"""
        text = raw_text.strip()
        if text.startswith("```json"):
            text = text[7:]
        elif text.startswith("```"):
            text = text[3:]
        if text.endswith("```"):
            text = text[:-3]
        return text.strip()
    
    def parse_json_response(response_text: str, response_type: str) -> Dict[str, str]:
        """Safely parse JSON response from OpenAI with error handling"""
        try:
            cleaned_text = clean_openai_json(response_text)
            print(f"Cleaned {response_type} response: {cleaned_text}")
            
            # Try to parse as JSON
            parsed_data = json.loads(cleaned_text)
            
            # Validate it's a dictionary
            if not isinstance(parsed_data, dict):
                print(f"Warning: {response_type} response is not a dictionary")
                return {}
                
            return parsed_data
            
        except json.JSONDecodeError as e:
            print(f"JSON decode error for {response_type}: {e}")
            print(f"Raw response: {response_text}")
            
            # Try to extract JSON from malformed response
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                try:
                    extracted_json = json_match.group(0)
                    parsed_data = json.loads(extracted_json)
                    if isinstance(parsed_data, dict):
                        return parsed_data
                except:
                    pass
                    
            return {}
        except Exception as e:
            print(f"Unexpected error parsing {response_type}: {e}")
            return {}
    
    for idx in unique_indices:
        job = df.iloc[idx]
        similarity_score = float(similarities[idx])
        similarity_percentage = round(similarity_score * 100, 2)
        original_job_desc = job.get("Full Job Description", "N/A")
        
        # Initialize variables
        job_desc = original_job_desc
        required_skills = []
        required_knowledge = []
        
        # Generate cleaned/comprehensive description using OpenAI
        if use_openai_summary and original_job_desc != "N/A":
            try:
                summary_prompt = (
                    "Extract a clear, comprehensive job description from the text below. "
                    "Focus on the relevant responsibilities of the career. "
                    "Write it concisely in a professional tone (1 paragraph). "
                    "Start with 'This career involves...'"
                    "Avoid mentioning overly detailed information such as the company, years of experience, etc."
                    "Keep it under 400 characters.\n\n"
                    f"JOB DESCRIPTION TEXT:\n{original_job_desc}\n\n"
                    "Return only the cleaned-up job description without any additional text."
                )
                
                skills_prompt = (
                    "ANALYZE THIS JOB DESCRIPTION AND EXTRACT ALL REQUIRED SKILLS WITH PROFICIENCY LEVELS:\n\n"
                    f"{original_job_desc}\n\n"
                    "EXTRACTION RULES:\n"
                    "1. Extract ONLY technical skills: programming languages, frameworks, libraries, tools, software, and platforms.\n"
                    "2. Assign a proficiency level for each skill: Basic, Intermediate, or Advanced.\n"
                    "3. Respond STRICTLY in JSON format as a dictionary: {\"Skill Name\": \"Level\", ...} without any additional text.\n"
                    "4. Be specific: if 'Python' is mentioned, include 'Python', not just 'programming'.\n"
                    "5. Be as specific as possible: if 'Python with Django' is mentioned, include 'Python' and 'Django' as separate entries.\n"
                    "6. Exclude non-technical or natural languages such as English, Malay, Mandarin.\n"
                    "7. Include skills mentioned in requirements, qualifications, or responsibilities sections.\n"
                    "8. Remove duplicates and keep the most specific term.\n"
                    "9. If multiple skills are mentioned together, create separate entries for each.\n"
                    "10. DO NOT include explanations, markdown, or code blocks.\n\n"
                    "EXAMPLE OUTPUT:\n"
                    "{\"Python\": \"Advanced\", \"Django\": \"Intermediate\", \"SQL\": \"Intermediate\"}"
                )

                knowledge_prompt = (
                    "ANALYZE THIS JOB DESCRIPTION AND EXTRACT ALL REQUIRED KNOWLEDGE AREAS WITH PROFICIENCY LEVELS:\n\n"
                    f"{original_job_desc}\n\n"
                    "EXTRACTION RULES:\n"
                    "1. Extract knowledge domains, concepts, methodologies, and specialized areas.\n"
                    "2. Assign a proficiency level for each: Basic, Intermediate, or Advanced.\n"
                    "3. Respond STRICTLY in JSON format as a dictionary: {\"Knowledge Name\": \"Level\", ...}\n"
                    "4. Examples: Algorithms, Data Structures, Machine Learning, Web Development, Cybersecurity.\n"
                    "5. Focus on knowledge areas, not just tools or technical skills.\n"
                    "6. Exclude non-technical languages.\n"
                    "7. Remove duplicates and keep the most specific term.\n"
                    "8. If multiple knowledge areas are mentioned together, create separate entries.\n"
                    "9. DO NOT include explanations, markdown, or code blocks.\n\n"
                    "EXAMPLE OUTPUT:\n"
                    "{\"Algorithms\": \"Intermediate\", \"Machine Learning\": \"Advanced\", \"Database Systems\": \"Intermediate\"}"
                )

                print(f"Processing job {idx} with OpenAI...")
                
                # Get job description summary
                job_desc = call_openai(summary_prompt, max_tokens=400)
                print(f"Job description summary: {job_desc}")

                # Extract skills
                try:
                    skills_response = call_openai(skills_prompt, max_tokens=300)
                    print(f"Raw skills response: {skills_response}")
                    
                    skills_data = parse_json_response(skills_response, "skills")
                    required_skills = skills_data
                    print(f"Parsed skills: {required_skills}")
                    
                except Exception as skills_error:
                    print(f"Skills extraction failed for job {idx}: {skills_error}")
                    required_skills = ["Error extracting skills"]

                # Extract knowledge
                try:
                    knowledge_response = call_openai(knowledge_prompt, max_tokens=300)
                    print(f"Raw knowledge response: {knowledge_response}")
                    
                    knowledge_data = parse_json_response(knowledge_response, "knowledge")
                    required_knowledge = knowledge_data
                    print(f"Parsed knowledge: {required_knowledge}")
                    
                except Exception as knowledge_error:
                    print(f"Knowledge extraction failed for job {idx}: {knowledge_error}")
                    required_knowledge = ["Error extracting knowledge"]

            except Exception as e:
                print(f"OpenAI error for job index {idx}: {e}")
                # fallback to original description
                job_desc = original_job_desc
                required_skills = ["Failed to extract skills"]
                required_knowledge = ["Failed to extract knowledge"]
        else:
            # If not using OpenAI summary
            job_desc = original_job_desc
            if use_openai_summary:
                required_skills = ["OpenAI extraction disabled"]
                required_knowledge = ["OpenAI extraction disabled"]
            else:
                required_skills = ["Enable OpenAI extraction for detailed skills"]
                required_knowledge = ["Enable OpenAI extraction for detailed knowledge"]

        top_matches.append(
            {
                "user_test_id": int(user_test_id),
                "job_index": int(idx),
                "similarity_score": similarity_score,
                "similarity_percentage": similarity_percentage,
                "job_title": job.get("Title", "N/A"),
                "job_description": job_desc,
                "required_skills": required_skills,
                "required_knowledge": required_knowledge
            }
        )
    
    return {"top_matches": top_matches}

# -----------------------------
# Check if everything is loaded
# -----------------------------
def is_initialized() -> bool:
    """Check if AI models and data are loaded"""
    return _tokenizer is not None and _model is not None and not df.empty

