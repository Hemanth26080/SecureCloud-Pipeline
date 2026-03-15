"""
Root-level conftest.py — ensures the project root is on sys.path
so `from app.main import app` works in all test modules.
pytest discovers this file automatically at collection time.
"""
import sys
import os

# Insert project root at the front of sys.path
sys.path.insert(0, os.path.dirname(__file__))
