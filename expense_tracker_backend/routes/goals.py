from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models.database import db
from models.goal import Goal
from datetime import datetime

goals_bp = Blueprint('goals', __name__, url_prefix='/goals')

@goals_bp.route('', methods=['GET'])
@jwt_required()
def get_goals():
    user_id = get_jwt_identity()
    goals = Goal.query.filter_by(user_id=user_id).all()
    return jsonify([g.to_dict() for g in goals]), 200

@goals_bp.route('', methods=['POST'])
@jwt_required()
def add_goal():
    user_id = get_jwt_identity()
    data = request.json or {}
    
    start_date_str = data.get('start_date', '').replace('Z', '+00:00')
    end_date_str = data.get('end_date', '').replace('Z', '+00:00')

    g = Goal(
        name=data['name'],
        # ── THE FIX: Silently copy the name to satisfy the DB constraint ──
        category=data['name'], 
        budget_amount=float(data['budget_amount']),
        start_date=datetime.fromisoformat(start_date_str),
        end_date=datetime.fromisoformat(end_date_str),
        alert_threshold=data.get('alert_threshold', None),
        user_id=user_id,
    )
    db.session.add(g)
    db.session.commit()
    return jsonify(g.to_dict()), 201

@goals_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_goal(id):
    g = Goal.query.get_or_404(id)
    data = request.json or {}
    
    g.name = data.get('name', g.name)
    # ── THE FIX: Keep the category mirrored if the name is updated ──
    g.category = data.get('name', g.name)
    
    g.budget_amount = float(data.get('budget_amount', g.budget_amount))
    g.alert_threshold = data.get('alert_threshold', g.alert_threshold)
    
    if 'start_date' in data:
        g.start_date = datetime.fromisoformat(data['start_date'].replace('Z', '+00:00'))
    if 'end_date' in data:
        g.end_date = datetime.fromisoformat(data['end_date'].replace('Z', '+00:00'))
        
    db.session.commit()
    return jsonify(g.to_dict()), 200

@goals_bp.route('/<int:goal_id>', methods=['DELETE'])
@jwt_required()
def delete_goal(goal_id):
    user_id = get_jwt_identity()
    goal = Goal.query.filter_by(id=goal_id, user_id=user_id).first()
    
    if not goal:
        return jsonify({"error": "Goal not found or unauthorized"}), 404
        
    db.session.delete(goal)
    db.session.commit()
    return jsonify({"message": "Goal deleted successfully"}), 200