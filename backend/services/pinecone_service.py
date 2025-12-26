# services/pinecone_service.py
# Real Pinecone service for vector database operations

import os
from typing import List, Dict, Any
from dotenv import load_dotenv
from pinecone import Pinecone

load_dotenv()

class PineconeService:
    """
    Real Pinecone Service for vector similarity search.
    """
    
    def __init__(self, index_name: str = "code-map"):
        self.index_name = index_name
        self.api_key = os.getenv("PINECONE_API_KEY")
        self.pc = None
        self.index = None
        self.initialized = False
        
        if not self.api_key:
            print("Warning: PINECONE_API_KEY not found. Using mock mode.")
            return
            
        try:
            self.pc = Pinecone(api_key=self.api_key)
            
            # Check if index exists, if not we'll need to create it
            existing_indexes = [idx.name for idx in self.pc.list_indexes()]
            
            if index_name in existing_indexes:
                self.index = self.pc.Index(index_name)
                self.initialized = True
                print(f"[OK] Connected to Pinecone index: {index_name}")
            else:
                print(f"Warning: Index '{index_name}' not found. Available indexes: {existing_indexes}")
                print("You may need to create the index and upload job embeddings first.")
                # Still mark as initialized so we can create/upsert
                self.initialized = True
                
        except Exception as e:
            print(f"Failed to initialize Pinecone: {e}")
    
    def create_index_if_needed(self, dimension: int = 384):
        """Create the index if it doesn't exist (384 dim for MiniLM-L6-v2)"""
        if not self.pc:
            return False
            
        try:
            existing_indexes = [idx.name for idx in self.pc.list_indexes()]
            
            if self.index_name not in existing_indexes:
                from pinecone import ServerlessSpec
                self.pc.create_index(
                    name=self.index_name,
                    dimension=dimension,
                    metric="cosine",
                    spec=ServerlessSpec(
                        cloud="aws",
                        region="us-east-1"
                    )
                )
                print(f"[OK] Created Pinecone index: {self.index_name}")
                
            self.index = self.pc.Index(self.index_name)
            self.initialized = True
            return True
            
        except Exception as e:
            print(f"Error creating index: {e}")
            return False
    
    def upsert_user(self, user_test_id: str, embedding: List[float], metadata: Dict[str, Any]) -> bool:
        """Store user embedding in Pinecone"""
        if not self.initialized or not self.index:
            print(f"Mock: Would upsert user {user_test_id}")
            return True
            
        try:
            self.index.upsert(
                vectors=[(user_test_id, embedding, metadata)],
                namespace="users"
            )
            print(f"[OK] Upserted user {user_test_id} to Pinecone")
            return True
        except Exception as e:
            print(f"Error upserting user: {e}")
            return False
    
    def upsert_jobs(self, jobs: List[Dict[str, Any]]) -> bool:
        """Batch upsert job embeddings"""
        if not self.initialized or not self.index:
            print(f"Mock: Would upsert {len(jobs)} jobs")
            return True
            
        try:
            vectors = []
            for job in jobs:
                vectors.append((
                    job["id"],
                    job["embedding"],
                    job.get("metadata", {})
                ))
            
            # Batch upsert in chunks of 100
            batch_size = 100
            for i in range(0, len(vectors), batch_size):
                batch = vectors[i:i + batch_size]
                self.index.upsert(vectors=batch, namespace="jobs")
                print(f"[OK] Upserted batch {i//batch_size + 1}/{(len(vectors)-1)//batch_size + 1}")
            
            return True
        except Exception as e:
            print(f"Error upserting jobs: {e}")
            return False
    
    def query_similar_jobs(self, user_embedding: List[float], top_k: int = 3) -> List[Dict[str, Any]]:
        """Query for similar jobs using user embedding"""
        if not self.initialized or not self.index:
            print(f"Mock: Returning mock jobs (Pinecone not initialized)")
            return self._get_mock_jobs()
            
        try:
            results = self.index.query(
                vector=user_embedding,
                top_k=top_k,
                include_metadata=True,
                namespace="jobs"
            )
            
            if not results.matches:
                print("No matches found in Pinecone, returning mock data")
                return self._get_mock_jobs()
            
            job_matches = []
            for match in results.matches:
                job_matches.append({
                    "id": match.id,
                    "score": match.score,
                    "metadata": match.metadata or {}
                })
            
            print(f"[OK] Found {len(job_matches)} similar jobs from Pinecone")
            return job_matches
            
        except Exception as e:
            print(f"Error querying Pinecone: {e}")
            return self._get_mock_jobs()
    
    def _get_mock_jobs(self) -> List[Dict[str, Any]]:
        """Return mock job data as fallback"""
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
    
    def delete_user(self, user_test_id: str) -> bool:
        """Delete user from Pinecone"""
        if not self.initialized or not self.index:
            print(f"Mock: Would delete user {user_test_id}")
            return True
            
        try:
            self.index.delete(ids=[user_test_id], namespace="users")
            return True
        except Exception as e:
            print(f"Error deleting user: {e}")
            return False
    
    def get_index_stats(self) -> Dict[str, Any]:
        """Get index statistics"""
        if not self.initialized or not self.index:
            return {"status": "not_initialized"}
            
        try:
            stats = self.index.describe_index_stats()
            return {
                "total_vectors": stats.total_vector_count,
                "namespaces": stats.namespaces
            }
        except Exception as e:
            return {"error": str(e)}
