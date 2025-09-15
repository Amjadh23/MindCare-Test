import json
import openai
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found. Please set it in your .env file.")

# Initialize OpenAI client
client = openai.OpenAI(api_key=OPENAI_API_KEY)


def call_openai(prompt: str, max_tokens=2000, temperature=0.2) -> str:
    """Send a prompt to OpenAI and return the model's text output."""
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {
                "role": "system",
                "content": "You are an assistant that returns clean, concise outputs.",
            },
            {"role": "user", "content": prompt},
        ],
        max_tokens=max_tokens,
        temperature=temperature,
    )
    return response.choices[0].message.content.strip()


def strip_json_codeblock(text: str) -> str:
    """Remove ```json and ``` from OpenAI output before parsing."""
    text = text.strip()
    if text.startswith("```json"):
        text = text[len("```json") :]
    elif text.startswith("```"):
        text = text[len("```") :]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


def generate_questions(user_input: str):
    # Extract topics
    topics = call_openai(
        f"""Extract all **coding-related** topics, skills, languages, libraries, and frameworks from this statement:
        '{user_input}'.
        Output them as a single comma-separated list. No numbering, no explanations, no extra words."""
    )
    print("\n[DEBUG] Extracted topics:", topics)

    # Extract all programming languages
    all_languages_text = call_openai(
        f"""From the following list of topics: '{topics}', extract all programming languages mentioned.
        Return a comma-separated list. If none are found, return 'None'."""
    )
    
    if all_languages_text.strip().lower() == "none":
        language_list = []
    else:
        language_list = [lang.strip() for lang in all_languages_text.split(",")]
    
    print("[DEBUG] Extracted languages:", language_list)
    
    # Generate exactly 5 coding questions distributed across languages
    coding_questions = []
    total_questions = 5
    
    if language_list:
        # Determine distribution per language
        num_languages = len(language_list)
        base_count = total_questions // num_languages
        remainder = total_questions % num_languages

        questions_per_language = {lang: base_count for lang in language_list}

        # Distribute remainder
        for i in range(remainder):
            questions_per_language[language_list[i]] += 1

        # Generate questions per language
        for lang, count in questions_per_language.items():
            if count == 0:
                continue
            coding_questions_text = call_openai(
                f"""Generate exactly {count} coding problems based on: '{topics}'.
                - Include a short code snippet in '{lang}' (≤30 lines).
                - Then write a question about that snippet.
                - The question text must contain **both the code snippet and the actual question about the snippet** in the same "question" field.
                - Difficulty ratio: 1 Easy, 1 Medium, 3 Hard (if {count} >=5, otherwise distribute proportionally).
                - Format each question as code (triple backticks) + text.
                - Only self-contained examples, no APIs or external files.
                - Use formal academic language appropriate for undergraduate or graduate students.
                - Do NOT include answers.
                - Return questions as JSON list, each object with:
                {{"question": "<code snippet embedded in question> followed by the question text", "difficulty": "Easy/Medium/Hard", "category": "Coding"}}"""
            )
            # Parse robustly
            cleaned_text = strip_json_codeblock(coding_questions_text)
            try:
                coding_temp = json.loads(cleaned_text)
                if isinstance(coding_questions, list):
                    coding_questions.extend(coding_temp)
            except json.JSONDecodeError as e:
                print(f"[ERROR] Failed to parse coding questions for {lang}:", e)
    
    # Generate non-coding questions
    non_coding_questions_text = call_openai(
        f"""Generate exactly 10 non-coding conceptual questions based on: '{topics}'.
        - No coding required.
        - Use formal academic language suitable for college-level students.
        - Cover definitions, theoretical concepts, practical applications, and real-world examples or practical applications.
        - Include higher-order thinking questions (analysis, synthesis, evaluation), not just memorization.
        - Ensure all topics are represented at least once.
        - Difficulty ratio: 1 Easy, 3 Medium, 6 Hard.
        - Return questions as JSON list, each object with:
          {{"question": "...", "difficulty": "Easy/Medium/Hard", "category": "Non-coding"}}"""
    )
    non_coding_questions = [
        q.strip()
        for q in non_coding_questions_text.replace("\n", "||").split("||")
        if q.strip()
    ]

    # Convert coding questions to MCQs
    coding_mcqs = []
    if coding_questions:
        coding_mcqs_text = call_openai(
            f"""Convert the following coding questions into JSON multiple-choice questions (MCQs):
            {coding_questions}

            Strict rules:
            - Return only valid JSON, no explanation or extra text.
            - Keep difficulty and category unchanged.
            - Each question must have exactly 4 options labeled "A", "B", "C", "D".
            - Only 1 option is correct; indicate it with "answer": "A"/"B"/"C"/"D".
            - Options format example: "A. Option text"
            - JSON format MUST be an array of objects like:
            [
              {{"question": "...", "options": ["A","B","C","D"], "answer":"A", "difficulty":"Easy", "category":"Coding"}}
            ]"""
        )
        cleaned_text = strip_json_codeblock(coding_mcqs_text)
        print("[DEBUG] Coding MCQs JSON:", cleaned_text)
        try:
            coding_mcqs = json.loads(cleaned_text)
            if not isinstance(coding_mcqs, list):
                print("[ERROR] coding_mcqs is not a list, returning empty list")
                coding_mcqs = []
        except json.JSONDecodeError as e:
            print("[ERROR] Failed to parse coding MCQs JSON:", e)
            coding_mcqs = []

    # Convert non-coding questions to MCQs
    non_coding_mcqs = []
    if non_coding_questions:
        non_coding_mcqs_text = call_openai(
            f"""Convert the following non-coding questions into JSON multiple-choice questions (MCQs):
            {non_coding_questions}

            Strict rules:
            - Return only valid JSON, no explanation or extra text.
            - Keep difficulty and category unchanged.
            - Each question must have exactly 4 options labeled "A", "B", "C", "D".
            - Only 1 option is correct; indicate it with "answer": "A"/"B"/"C"/"D".
            - Options format example: "A. Option text"
            - JSON format MUST be an array of objects like:
            [
              {{"question": "...", "options": ["A","B","C","D"], "answer":"A", "difficulty":"Easy", "category":"Non-coding"}}
            ]"""
        )
        cleaned_text = strip_json_codeblock(non_coding_mcqs_text)
        print("[DEBUG] Non-coding MCQs JSON:", cleaned_text)
        try:
            non_coding_mcqs = json.loads(cleaned_text)
            if not isinstance(non_coding_mcqs, list):
                print("[ERROR] non_coding_mcqs is not a list, returning empty list")
                non_coding_mcqs = []
        except json.JSONDecodeError as e:
            print("[ERROR] Failed to parse non-coding MCQs JSON:", e)
            non_coding_mcqs = []

    # Merge all questions and assign unique IDs
    all_questions = coding_mcqs + non_coding_mcqs

    print("[DEBUG] Total questions generated:", len(all_questions))
 
    return {
        "questions": all_questions,
    }