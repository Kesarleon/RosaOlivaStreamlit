#!/usr/bin/env python3
"""
Simple script to run the Rosa Oliva Geoespacial Streamlit app
"""

import os
import sys
import subprocess
from pathlib import Path

def check_requirements():
    """Check if required packages are installed"""
    try:
        import streamlit
        import folium
        import pandas
        import geopandas
        print("✅ All required packages are installed")
        return True
    except ImportError as e:
        print(f"❌ Missing required package: {e}")
        print("Please run: pip install -r requirements.txt")
        return False

def load_env_file():
    """Load environment variables from .env file if it exists"""
    env_file = Path(".env")
    if env_file.exists():
        try:
            from dotenv import load_dotenv
            load_dotenv()
            print("✅ Loaded environment variables from .env file")
        except ImportError:
            print("⚠️  python-dotenv not installed, skipping .env file loading")
            print("   Install with: pip install python-dotenv")
    else:
        print("ℹ️  No .env file found. Copy .env.example to .env and configure your API keys")

def check_api_keys():
    """Check if API keys are configured"""
    google_key = os.getenv("GOOGLE_PLACES_API_KEY")
    inegi_key = os.getenv("INEGI_API_KEY")
    
    if not google_key:
        print("⚠️  GOOGLE_PLACES_API_KEY not configured - will use default ratings")
    else:
        print("✅ Google Places API key configured")
    
    if not inegi_key:
        print("⚠️  INEGI_API_KEY not configured - will use simulated business data")
    else:
        print("✅ INEGI API key configured")

def run_app():
    """Run the Streamlit app"""
    print("\n🚀 Starting Rosa Oliva Geoespacial app...")
    print("   App will be available at: http://localhost:8501")
    print("   Press Ctrl+C to stop the app\n")
    
    try:
        subprocess.run([
            sys.executable, "-m", "streamlit", "run", "app.py",
            "--server.port=8501",
            "--server.address=localhost"
        ])
    except KeyboardInterrupt:
        print("\n👋 App stopped by user")
    except Exception as e:
        print(f"❌ Error running app: {e}")

def main():
    """Main function"""
    print("🏪 Rosa Oliva Geoespacial - Streamlit App")
    print("=" * 50)
    
    # Check requirements
    if not check_requirements():
        sys.exit(1)
    
    # Load environment variables
    load_env_file()
    
    # Check API keys
    check_api_keys()
    
    # Run the app
    run_app()

if __name__ == "__main__":
    main()