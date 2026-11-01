from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models.database import db
from models.subscriptions import Subscription
from datetime import datetime

subscriptions_bp = Blueprint('subscriptions', __name__, url_prefix='/subscriptions')

@subscriptions_bp.route('', methods=['GET'])
@jwt_required()
def get_subscriptions():
    try:
        user_id = get_jwt_identity()
        subscriptions = Subscription.query.filter_by(user_id=user_id).all()
        return jsonify([s.to_dict() for s in subscriptions]), 200
    except Exception as e:
        return jsonify({'message': str(e)}), 500

@subscriptions_bp.route('', methods=['POST'])
@jwt_required()
def add_subscription():
    try:
        user_id = get_jwt_identity()
        data = request.get_json() or {}

        # Parse the next billing date
        date_str = data.get('next_billing_date')
        try:
            parsed_date = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
        except (ValueError, TypeError):
            parsed_date = datetime.now()

        s = Subscription(
            title=data.get('title'),
            amount=float(data.get('amount')),
            is_expense=data.get('is_expense', True),
            category=data.get('category'),
            payment_method=data.get('payment_method', 'Cash'),
            frequency=data.get('frequency', 'monthly'),
            next_billing_date=parsed_date,
            user_id=user_id,
        )

        db.session.add(s)
        db.session.commit()
        return jsonify(s.to_dict()), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({'message': 'Failed to save subscription', 'error': str(e)}), 500

@subscriptions_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_subscription(id):
    try:
        s = Subscription.query.get_or_404(id)
        data = request.get_json() or {}

        s.title = data.get('title', s.title)
        s.amount = data.get('amount', s.amount)
        s.category = data.get('category', s.category)
        s.payment_method = data.get('payment_method', s.payment_method)
        s.frequency = data.get('frequency', s.frequency)
        
        if 'next_billing_date' in data:
            s.next_billing_date = datetime.fromisoformat(data['next_billing_date'].replace('Z', '+00:00'))

        db.session.commit()
        return jsonify(s.to_dict()), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@subscriptions_bp.route('/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_subscription(id):
    try:
        s = Subscription.query.get_or_404(id)
        db.session.delete(s)
        db.session.commit()
        return jsonify({'message': 'deleted'}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500