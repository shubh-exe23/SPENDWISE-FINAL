import os
from datetime import timedelta
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / '.env')

class Config:
    SQLALCHEMY_DATABASE_URI = os.environ['DATABASE_URL']
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = os.environ['JWT_SECRET_KEY']
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=30)
    CORS_ORIGINS = [origin.strip() for origin in os.getenv('CORS_ORIGINS', '').split(',') if origin.strip()]
    SQLALCHEMY_ENGINE_OPTIONS = {'pool_pre_ping': True, 'pool_recycle': 300}
    if SQLALCHEMY_DATABASE_URI.startswith(('postgresql:', 'postgresql+psycopg2:')):
        SQLALCHEMY_ENGINE_OPTIONS.update({
            'pool_size': 2 if os.getenv('VERCEL') else 5,
            'max_overflow': 0 if os.getenv('VERCEL') else 5, 'pool_timeout': 10,
            'connect_args': {'connect_timeout': 10, 'sslmode': 'require'},
        })
    if len(JWT_SECRET_KEY) < 32 or JWT_SECRET_KEY == 'your_secret_key_change_this':
        raise ValueError('JWT_SECRET_KEY must be a strong deployment secret')
