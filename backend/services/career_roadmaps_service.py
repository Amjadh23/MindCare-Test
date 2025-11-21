import os
import json
import re
from dotenv import load_dotenv
from langchain_openai import ChatOpenAI
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
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found. Please set it in your .env file.")

# -----------------------------
# Initialize LLM
# -----------------------------
llm = ChatOpenAI(model="gpt-4o", temperature=0.2)


def generate_roadmap_with_openai(skill_status: dict, knowledge_status: dict) -> dict:
    """
    Generate career roadmap topics and subtopics using OpenAI.
    Uses the skill_status and knowledge_status from job_skill_matches.
    """

    prompt = f"""
    Create a structured career roadmap based on skill gap analysis:
    
    Skill Status: {skill_status}
    Knowledge Status: {knowledge_status}
    
    Analyze the gaps between user's current level and required level for each skill/knowledge.
    Create a hierarchical roadmap with main topics and specific subtopics.
    
    Return ONLY a JSON object with this exact structure:
    {{
        "topics": {{
            "Main Topic 1": "Beginner|Intermediate|Expert|Advanced",
            "Main Topic 2": "Beginner|Intermediate|Expert|Advanced"
        }},
        "sub_topics": {{
            "Main Topic 1": [
                "Specific Subtopic 1",
                "Specific Subtopic 2", 
            ],
            "Main Topic 2": [
                "Specific Subtopic 1",
                "Specific Subtopic 2",
            ]
        }}
    }}
    
    Rules:
    - Focus on skills/knowledge where status is "Missing" or user_level is lower than required_level
    - Create appropriate subtopics based on topic scope
    - Subtopic format: Concise, technical concepts only (like "React Hooks", "State Management", "Component Lifecycle")
    - Assign appropriate proficiency levels based on the gap analysis
    - Return ONLY the JSON
    """

    try:
        response = llm.invoke(prompt)

        # find JSON in the response
        json_match = re.search(r"\{.*\}", response.content, re.DOTALL)
        if json_match:
            roadmap_data = json.loads(json_match.group())
            return roadmap_data
        else:
            # Fallback if no JSON found
            return get_fallback_roadmap(skill_status, knowledge_status)

    except Exception as e:
        print(f"OpenAI API error: {e}")
        return get_fallback_roadmap(skill_status, knowledge_status)


def get_fallback_roadmap(skill_status: dict, knowledge_status: dict) -> dict:
    """
    Create a simple fallback roadmap when OpenAI fails.
    """
    # extract skills that need improvement
    skills_to_improve = []

    for skill_name, skill_data in skill_status.items():
        if isinstance(skill_data, dict):
            status = skill_data.get("status", "")
            required_level = skill_data.get("required_level", "")
            user_level = skill_data.get("user_level", "")

            if status == "Missing" or (
                user_level and required_level and user_level != required_level
            ):
                skills_to_improve.append(skill_name)

    # create simple roadmap structure with proper subtopics
    topics = {}
    sub_topics = {}

    for skill in skills_to_improve[:5]:  # limit to top 5 skills
        topics[skill] = "Intermediate"

        # generate relevant technical subtopics based on the skill
        if "react" in skill.lower() or "frontend" in skill.lower():
            sub_topics[skill] = [
                "React Components",
                "Hooks and State Management",
                "React Router",
                "Context API",
                "Performance Optimization",
            ]
        elif "javascript" in skill.lower():
            sub_topics[skill] = [
                "ES6+ Features",
                "Async/Await Patterns",
                "DOM Manipulation",
                "Event Handling",
                "Modern JS Syntax",
            ]
        elif "git" in skill.lower() or "version" in skill.lower():
            sub_topics[skill] = [
                "Git Fundamentals",
                "Branching Strategies",
                "Merge Conflicts",
                "GitHub/GitLab Workflows",
                "Version Control Best Practices",
            ]
        else:
            # generic fallback with technical subtopics
            sub_topics[skill] = [
                f"{skill} Fundamentals",
                f"Advanced {skill} Concepts",
                f"{skill} Best Practices",
                f"{skill} Tools and Ecosystem",
                f"{skill} Implementation Patterns",
            ]

    # add fallback if no skills found
    if not topics:
        topics = {
            "Frontend Development": "Intermediate",
            "Backend Development": "Beginner",
        }
        sub_topics = {
            "Frontend Development": [
                "JavaScript ES6+",
                "React/Vue Framework",
                "State Management",
                "CSS Frameworks",
                "Build Tools",
            ],
            "Backend Development": [
                "Server Architecture",
                "API Design",
                "Database Management",
                "Authentication Systems",
                "Deployment Strategies",
            ],
        }

    return {"topics": topics, "sub_topics": sub_topics}


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
