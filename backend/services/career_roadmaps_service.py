import os
import json
import re
from dotenv import load_dotenv
from langchain_groq import ChatGroq
from models.firestore_models import (
    get_recommendation_id_by_user_test_id,
    get_user_job_skill_matches,
    create_career_roadmap,
    get_career_roadmap,
)

# -----------------------------
# Load environment variables
# -----------------------------
load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    raise ValueError("GROQ_API_KEY not found. Please set it in your .env file.")

# -----------------------------
# Initialize LLM
# -----------------------------
llm = ChatGroq(model="llama-3.3-70b-versatile", temperature=0.2, groq_api_key=GROQ_API_KEY)


def generate_roadmap_with_openai(skill_status: dict, knowledge_status: dict) -> dict:
    """
    Generate career roadmap topics and subtopics using OpenAI.
    Uses the skill_status and knowledge_status from job_skill_matches.
    """

    prompt = f"""
    Create a structured career roadmap based on skill gap analysis:

    Input Data:
    - Skill Status: {skill_status}
    - Knowledge Status: {knowledge_status}

    Task:
    Identify all skills and knowledge areas where:
    - status == "Missing", AND
    - user_level < required_level
    
    Analyze the gaps between user's current level and required level for each skill/knowledge.
    Create a hierarchical roadmap with main topics and subtopics.
    
    Return ONLY a JSON object with this exact structure:
    {{
        "topics": {{
            "Main Topic 1": "Basic/Intermediate/Expert/Advanced",
            "Main Topic 2": "Basic/Intermediate/Expert/Advanced"
        }},
        "sub_topics": {{
            "Main Topic 1": [
                "Subtopic 1",
                "Subtopic 2", 
            ],
            "Main Topic 2": [
                "Subtopic 1",
                "Subtopic 2",
            ]
        }}
    }}
    
    For each affected skill/knowledge area, generate:
    1. A Main Topic (professional, concise, technical)
    2. An appropriate proficiency level (Basic / Intermediate / Advanced / Expert) ONLY
    3. Subtopics that fully cover what the user must learn
        - Subtopics must be: concise, technical, non-generic, actionable
        - Cover the complete domain but avoid unnecessary depth
    
    Return ONLY the JSON object, no markdown code blocks or explanations.
    """

    try:
        response = llm.invoke(prompt)
        response_text = response.content.strip()
        
        # Remove markdown code blocks if present
        if response_text.startswith("```json"):
            response_text = response_text[7:]
        elif response_text.startswith("```"):
            response_text = response_text[3:]
        if response_text.endswith("```"):
            response_text = response_text[:-3]
        response_text = response_text.strip()

        # find JSON in the response
        json_match = re.search(r"\{.*\}", response_text, re.DOTALL)
        if json_match:
            roadmap_data = json.loads(json_match.group())
            return roadmap_data

    except json.JSONDecodeError as e:
        print(f"JSON parse error in roadmap generation: {e}")
    except Exception as e:
        print(f"Roadmap API error: {e}")
    
    # Return fallback roadmap if generation fails
    print("Returning fallback roadmap due to generation error")
    return {
        "topics": {"Learning Path": "Basic"},
        "sub_topics": {"Learning Path": ["Review skill gaps", "Practice coding exercises", "Build portfolio projects"]}
    }


def compute_career_roadmaps(user_test_id: str) -> dict:
    """
    Compute Career Roadmaps for all jobs based on the given user_test_id.
    Now uses job_skill_matches collection which already has skill gap analysis.
    """
    try:
        # get all job skill matches for this user
        job_skill_matches = get_user_job_skill_matches(user_test_id)

        if not job_skill_matches:
            return {"error": "No job skill matches found for this user."}

        # Get the recommendation document ID for this user_test_id
        recommendation_id = get_recommendation_id_by_user_test_id(user_test_id)

        if not recommendation_id:
            return {"error": "No recommendation found for this user test ID."}

        # generate roadmap for each job
        generated_roadmaps = {}

        for job_match in job_skill_matches:
            job_match_id = job_match.get("job_match_id")
            job_title = job_match.get("job_title", f"Job_{job_match_id}")
            skill_status = job_match.get("skill_status", {})
            knowledge_status = job_match.get("knowledge_status", {})

            # generate roadmap content using OpenAI
            roadmap_content = generate_roadmap_with_openai(
                skill_status, knowledge_status
            )

            # save to Firestore (using job_match_id as job_index)
            create_career_roadmap(
                user_test_id=user_test_id,
                job_index=job_match_id,
                rec_id=recommendation_id,
                topics=roadmap_content["topics"],
                sub_topics=roadmap_content["sub_topics"],
            )

            generated_roadmaps[job_match_id] = {
                "job_title": job_title,
                "roadmap": roadmap_content,
            }

        return {
            "message": f"Successfully generated {len(generated_roadmaps)} career roadmaps",
            "data": generated_roadmaps,
        }

    except Exception as e:
        print(f"Error computing career roadmaps: {e}")
        return {"error": f"Failed to compute career roadmaps: {str(e)}"}


def retrieve_career_roadmap(user_test_id: str, job_index: str) -> dict:
    """
    Retrieve the Career Roadmap for a specific job based on user_test_id and job_index.
    """
    try:
        roadmap = get_career_roadmap(user_test_id, job_index)

        if not roadmap:
            return {"error": f"No career roadmap found for job index: {job_index}"}

        return {"message": "Career roadmap retrieved successfully", "data": roadmap}

    except Exception as e:
        print(f"Error retrieving career roadmap: {e}")
        return {"error": f"Failed to retrieve career roadmap: {str(e)}"}
