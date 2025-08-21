import pytest
import sys
import os
from fastapi.testclient import TestClient

# Add the app directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'app'))

from main import app

client = TestClient(app)

class TestTextAnalyzer:
    """Test cases for the text analyzer API"""
    
    def test_health_check(self):
        """Test the health check endpoint"""
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "text-analyzer"
        assert "timestamp" in data

    def test_health_endpoint(self):
        """Test the Kubernetes-style health endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"

    def test_analyze_simple_text(self):
        """Test analyzing simple text"""
        test_text = "I love cloud engineering!"
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["original_text"] == test_text
        assert data["word_count"] == 4
        assert data["character_count"] == 23
        assert "analysis_timestamp" in data

    def test_analyze_single_word(self):
        """Test analyzing a single word"""
        test_text = "hello"
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["original_text"] == test_text
        assert data["word_count"] == 1
        assert data["character_count"] == 5

    def test_analyze_empty_string(self):
        """Test analyzing empty string should return error"""
        response = client.post(
            "/analyze",
            json={"text": ""}
        )
        assert response.status_code == 400
        assert "Text cannot be empty" in response.json()["detail"]

    def test_analyze_whitespace_only(self):
        """Test analyzing whitespace-only text"""
        test_text = "   "
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["original_text"] == test_text
        assert data["word_count"] == 0  # split() on whitespace returns empty list
        assert data["character_count"] == 3

    def test_analyze_multiple_spaces(self):
        """Test analyzing text with multiple spaces"""
        test_text = "hello    world"
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["original_text"] == test_text
        assert data["word_count"] == 2
        assert data["character_count"] == 14

    def test_analyze_newlines(self):
        """Test analyzing text with newlines"""
        test_text = "hello\nworld"
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["original_text"] == test_text
        assert data["word_count"] == 2
        assert data["character_count"] == 11

    def test_analyze_special_characters(self):
        """Test analyzing text with special characters"""
        test_text = "Hello, world! How are you?"
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["original_text"] == test_text
        assert data["word_count"] == 5
        assert data["character_count"] == 26

    def test_analyze_unicode_characters(self):
        """Test analyzing text with unicode characters"""
        test_text = "Hello 世界! 🌍"
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["original_text"] == test_text
        assert data["word_count"] == 3
        assert data["character_count"] == 10

    def test_analyze_very_long_text(self):
        """Test analyzing text that exceeds the limit"""
        test_text = "a" * 10001  # Exceeds 10,000 character limit
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 400
        assert "Text too long" in response.json()["detail"]

    def test_analyze_text_at_limit(self):
        """Test analyzing text exactly at the character limit"""
        test_text = "a" * 10000  # Exactly at 10,000 character limit
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["word_count"] == 1
        assert data["character_count"] == 10000

    def test_missing_text_field(self):
        """Test request without text field"""
        response = client.post(
            "/analyze",
            json={}
        )
        assert response.status_code == 422  # Validation error

    def test_invalid_json(self):
        """Test request with invalid JSON"""
        response = client.post(
            "/analyze",
            data="invalid json"
        )
        assert response.status_code == 422

    def test_non_string_text(self):
        """Test request with non-string text field"""
        response = client.post(
            "/analyze",
            json={"text": 123}
        )
        assert response.status_code == 422  # Validation error

    def test_response_format(self):
        """Test that response has correct format and types"""
        test_text = "Testing response format"
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        
        # Check all required fields are present
        required_fields = ["original_text", "word_count", "character_count", "analysis_timestamp"]
        for field in required_fields:
            assert field in data
        
        # Check data types
        assert isinstance(data["original_text"], str)
        assert isinstance(data["word_count"], int)
        assert isinstance(data["character_count"], int)
        assert isinstance(data["analysis_timestamp"], str)
        
        # Check that counts are non-negative
        assert data["word_count"] >= 0
        assert data["character_count"] >= 0

    def test_timestamp_format(self):
        """Test that timestamp is in ISO format"""
        test_text = "Testing timestamp"
        response = client.post(
            "/analyze",
            json={"text": test_text}
        )
        assert response.status_code == 200
        data = response.json()
        
        timestamp = data["analysis_timestamp"]
        # Should end with 'Z' for UTC
        assert timestamp.endswith('Z')
        # Should be parseable as ISO format
        from datetime import datetime
        parsed_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        assert parsed_time is not None