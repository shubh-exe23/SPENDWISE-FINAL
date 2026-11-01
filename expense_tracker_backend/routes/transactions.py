from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models.database import db
from models.transaction import Transaction
from datetime import datetime, timedelta
import json
import google.generativeai as genai

transactions_bp = Blueprint('transactions', __name__, url_prefix='/transactions')

@transactions_bp.route('', methods=['GET'])
@jwt_required()
def get_transactions():
    try:
        user_id = get_jwt_identity()
        transactions = Transaction.query.filter_by(user_id=user_id).all()
        return jsonify([t.to_dict() for t in transactions]), 200
    except Exception as e:
        print(f"Error fetching transactions: {e}")
        return jsonify({'message': str(e)}), 500


@transactions_bp.route('', methods=['POST'])
@jwt_required()
def add_transaction():
    try:
        user_id = get_jwt_identity()
        data = request.get_json() or {}

        title = data.get('title')
        amount = data.get('amount')
        category = data.get('category')
        date_str = data.get('date')
        is_expense = data.get('is_expense', True)
        
        # ── 1. CATCH THE NEW PAYMENT METHOD ──
        payment_method = data.get('payment_method', 'Cash') 

        if not title or amount is None or not category or not date_str:
            return jsonify({'message': 'Missing required fields'}), 400

        try:
            parsed_date = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        except ValueError:
            parsed_date = datetime.now()

        t = Transaction(
            title=title,
            amount=float(amount),
            is_expense=bool(is_expense),
            date=parsed_date,
            category=category,
            payment_method=payment_method, # ── 2. SAVE IT TO THE DATABASE ──
            user_id=user_id,
        )

        db.session.add(t)
        db.session.commit()
        return jsonify(t.to_dict()), 201

    except Exception as e:
        db.session.rollback()
        print(f"Error saving transaction: {e}")
        return jsonify({'message': 'Failed to save transaction', 'error': str(e)}), 500


@transactions_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_transaction(id):
    try:
        txn = Transaction.query.get_or_404(id)
        data = request.get_json() or {}

        txn.title = data.get('title', txn.title)
        txn.amount = data.get('amount', txn.amount)
        txn.category = data.get('category', txn.category)
        txn.payment_method = data.get('payment_method', txn.payment_method)
        
        # Note: If you want them to be able to edit the date too:
        if 'date' in data:
            txn.date = datetime.fromisoformat(data['date'].replace('Z', '+00:00'))

        db.session.commit()
        return jsonify(txn.to_dict()), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@transactions_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_transaction(id):
    try:
        txn = Transaction.query.get_or_404(id)
        db.session.delete(txn)
        db.session.commit()
        return jsonify({'message': 'deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


# ════════════════════════════════════════════════════════════
# ── AI MAGIC ENTRY ENDPOINT ──
# ════════════════════════════════════════════════════════════
@transactions_bp.route('/magic', methods=['POST'])
@jwt_required()
def magic_entry():
    user_id = get_jwt_identity()
    data = request.get_json() or {}
    text = data.get('text', '')

    if not text:
        return jsonify({'message': 'No text provided'}), 400

    # Pass the exact current date to the AI so it understands "yesterday" or "last Friday"
    now_iso = datetime.now().isoformat()
    
    prompt = f"""
    Extract the transaction details from this text: "{text}"
    Today's date/time is: {now_iso}. Use this to calculate exact timestamps.
    
    Respond STRICTLY in valid JSON format. Do not use markdown blocks like ```json.
    Keys required:
    - title (string, short description of the purchase/income)
    - amount (number)
    - category (string, capitalize first letter, e.g., Food, Travel, Bills)
    - is_expense (boolean, true if money was spent, false if money was received)
    - payment_method (string, infer if they say card/cash/UPI, otherwise default to 'Cash')
    - date (string, ISO 8601 format like YYYY-MM-DDTHH:MM:SSZ)
    """

    try:
        model = genai.GenerativeModel('gemini-1.5-flash')
        response = model.generate_content(prompt)
        
        # Clean up the response to ensure it's pure JSON
        raw_json = response.text.strip().removeprefix('```json').removesuffix('```').strip()
        parsed = json.loads(raw_json)

        # Build the actual Database object directly from the AI's brain
        t = Transaction(
            title=parsed.get('title', 'Magic Entry'),
            amount=float(parsed.get('amount', 0)),
            is_expense=bool(parsed.get('is_expense', True)),
            date=datetime.fromisoformat(parsed.get('date').replace('Z', '+00:00')),
            category=parsed.get('category', 'Uncategorized'),
            payment_method=parsed.get('payment_method', 'Cash'),
            user_id=user_id,
        )

        db.session.add(t)
        db.session.commit()
        
        # Return the saved object to Flutter so it instantly appears in the UI
        return jsonify(t.to_dict()), 201

    except Exception as e:
        db.session.rollback()
        print(f"Magic Entry Error: {e}")
        return jsonify({'message': 'AI failed to parse', 'error': str(e)}), 500


# ════════════════════════════════════════════════════════════
# ── BULK CLEAR TRANSACTIONS ENDPOINT ──
# ════════════════════════════════════════════════════════════
@transactions_bp.route('/clear', methods=['DELETE'])
@jwt_required()
def clear_transactions():
    try:
        user_id = get_jwt_identity()
        data = request.get_json(silent=True)
        period = data.get('period') if isinstance(data, dict) else None
        normalized_period = period.strip().lower() if isinstance(period, str) else None
        if normalized_period not in {'today', 'yesterday', 'this week', 'this month', 'all time'}:
            return jsonify({'error': 'A valid period is required'}), 400
        
        now = datetime.now()
        query = Transaction.query.filter_by(user_id=user_id)
        
        if normalized_period == 'today':
            start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
            query = query.filter(Transaction.date >= start_of_day)
            
        elif normalized_period == 'yesterday':
            start_of_yesterday = (now - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
            end_of_yesterday = start_of_yesterday + timedelta(days=1)
            query = query.filter(Transaction.date >= start_of_yesterday, Transaction.date < end_of_yesterday)
            
        elif normalized_period == 'this week':
            # isoweekday() returns Mon=1 to Sun=7. Modulo 7 converts Sunday to 0.
            # This perfectly syncs with the Sunday-start logic we built in Dart!
            days_to_subtract = now.isoweekday() % 7
            start_of_week = (now - timedelta(days=days_to_subtract)).replace(hour=0, minute=0, second=0, microsecond=0)
            query = query.filter(Transaction.date >= start_of_week)
            
        elif normalized_period == 'this month':
            start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
            query = query.filter(Transaction.date >= start_of_month)
            
        # Only an explicitly validated 'all time' may keep the query unrestricted by date.
        
        # Execute bulk delete
        deleted_count = query.delete(synchronize_session=False)
        db.session.commit()
        
        return jsonify({'message': 'success', 'deleted_count': deleted_count}), 200
        
    except Exception as e:
        db.session.rollback()
        print(f"Clear Error: {e}")
        return jsonify({'error': str(e)}), 500