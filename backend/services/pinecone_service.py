# services/pinecone_service.py
# Mock Pinecone service - replace with real implementation when you have Pinecone API key

import os
from typing import List, Dict, Any
from dotenv import load_dotenv

load_dotenv()

class PineconeService:
    """
    Mock Pinecone Service - provides stub methods for development.
    To use real Pinecone:
    1. Install: pip install pinecone-client
    2. Set PINECONE_API_KEY in .env
    3. Replace this mock with actual implementation
    """
    
    def __init__(self, index_name: str = "code-map"):
        self.index_name = index_name
        self.api_key = os.getenv("PINECONE_API_KEY")
        self.initialized = False
        
        if not self.api_key:
            print("Warning: PINECONE_API_KEY not found. Using mock Pinecone service.")
        else:
            try:
                # Uncomment to use real Pinecone:
                # from pinecone import Pinecone
                # self.pc = Pinecone(api_key=self.api_key)
                # self.index = self.pc.Index(index_name)
                # self.initialized = True
                print(f"Pinecone service initialized for index: {index_name}")
            except Exception as e:
                print(f"Failed to initialize Pinecone: {e}")
    
    def upsert_user(self, user_test_id: str, embedding: List[float], metadata: Dict[str, Any]) -> bool:
        """Mock upsert - stores user embedding"""
        if not self.initialized:
            print(f"Mock: Would upsert user {user_test_id} with embedding of {len(embedding)} dims")
            return True
        # Real implementation would call: self.index.upsert(vectors=[(user_test_id, embedding, metadata)])
        return True
    
    def query_similar_jobs(self, user_embedding: List[float], top_k: int = 3) -> List[Dict[str, Any]]:
        """Mock query - returns empty list for now"""
        if not self.initialized:
            print(f"Mock: Would query for {top_k} similar jobs")
            # Return mock data for testing
            return [
                {
                    "id": "mock_job_1",
                    "score": 0.85,
                    "metadata": {
                        "title": "Software Developer",
                        "description": "Full-stack development role focusing on web applications.",
                        "job_id": "mock_1",
                        "required_skills": '{"Python": "Intermediate", "JavaScript": "Intermediate"}',
                        "required_knowledge": '{"Web Development": "Intermediate", "Databases": "Basic"}'
                    }
                },
                {
                    "id": "mock_job_2", 
                    "score": 0.78,
                    "metadata": {
                        "title": "Data Analyst",
                        "description": "Analyze data to provide business insights.",
                        "job_id": "mock_2",
                        "required_skills": '{"Python": "Intermediate", "SQL": "Advanced"}',
                        "required_knowledge": '{"Data Analysis": "Intermediate", "Statistics": "Basic"}'
                    }
                },
                {
                    "id": "mock_job_3",
                    "score": 0.72,
                    "metadata": {
                        "title": "Backend Developer",
                        "description": "Build and maintain server-side applications.",
                        "job_id": "mock_3",
                        "required_skills": '{"Python": "Advanced", "Django": "Intermediate"}',
                        "required_knowledge": '{"APIs": "Intermediate", "Cloud Computing": "Basic"}'
                    }
                }
            ]
        # Real implementation would call: self.index.query(vector=user_embedding, top_k=top_k, include_metadata=True)
        return []
    
    def delete_user(self, user_test_id: str) -> bool:
        """Mock delete"""
        if not self.initialized:
            print(f"Mock: Would delete user {user_test_id}")
            return True
        return True
