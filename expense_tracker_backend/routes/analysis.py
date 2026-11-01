from flask import Blueprint, jsonify, request  # ── ADDED 'request' HERE ──
from flask_jwt_extended import jwt_required, get_jwt_identity
import google.generativeai as genai
import os
from models.database import db
from models.transaction import Transaction
from datetime import datetime, timedelta

analysis_bp = Blueprint('analysis', __name__, url_prefix='/analysis')

# Make sure you configure your API key here or in your main app.py!
# genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))

@analysis_bp.route('/insights', methods=['GET'])
@jwt_required()
def get_insights():
    user_id = get_jwt_identity()
    
    # ── GRAB THE CURRENCY FROM THE FLUTTER APP (Defaults to INR if missing) ──
    user_currency = request.args.get('currency', '₹ INR')
    
    # Fetch transactions from the last 30 days
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    txns = Transaction.query.filter(
        Transaction.user_id == user_id, 
        Transaction.date >= thirty_days_ago
    ).all()
    
    if not txns:
        return jsonify({"insights": ["✨ Not enough data yet. Add some transactions to get personalized insights!"]}), 200
        
    total_income = sum(t.amount for t in txns if not t.is_expense)
    total_expense = sum(t.amount for t in txns if t.is_expense)
    
    # Aggregate category spending
    categories = {}
    for t in txns:
        if t.is_expense:
            categories[t.category] = categories.get(t.category, 0) + t.amount
            
    # ── INJECT THE CURRENCY DIRECTLY INTO THE PROMPT ──
    prompt = f"""
    You are a concise, highly intelligent financial advisor. 
    
    CRITICAL INSTRUCTION: You MUST use the exact currency format "{user_currency}" for ALL monetary values in your response. Do absolutely NOT use the $ symbol unless "{user_currency}" explicitly contains it.
    
    Here is the user's spending data for the last 30 days:
    - Total Income: {user_currency} {total_income}
    - Total Expenses: {user_currency} {total_expense}
    - Expense Categories Breakdown: {categories}
    
    Analyze this and provide exactly 3 short, punchy, and actionable financial insights. 
    Start each bullet point with a relevant emoji. 
    Do not include any introductory or concluding text. Just the 3 bullet points separated by newlines.
    """
    
    try:
        # Changed to 1.5-flash as 3.6 does not exist
        model = genai.GenerativeModel('gemini-3.6-flash') 
        response = model.generate_content(prompt)
        
        # Clean up the response into a list of strings
        insights = [line.strip().lstrip('*- ') for line in response.text.strip().split('\n') if line.strip()]
        return jsonify({"insights": insights[:3]}), 200
    except Exception as e:
        return jsonify({"insights": ["⚠️ AI is currently taking a break. Please try again later!"]}), 500